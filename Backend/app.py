import os
import numpy as np
from flask import Flask, Response, jsonify, request
from ultralytics import YOLO
import cv2
import easyocr
import firebase_admin
from firebase_admin import credentials, firestore, storage

# Initialize Flask
app = Flask(__name__)

# Firebase Admin SDK setup (Initialize only once)
if not firebase_admin._apps:
    cred = credentials.Certificate(os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json'))
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'fypro-417ee.appspot.com'
    })

# Firestore client
db = firestore.client()

# Firebase storage bucket
bucket = storage.bucket()

# Load YOLO model
model_path = os.path.join(os.path.dirname(__file__), 'models', 'best_float32.tflite')
model = YOLO(model_path, task="detect")

# Initialize EasyOCR Reader
reader = easyocr.Reader(['en'])  # Specify language

# Directory for uploaded images
UPLOAD_FOLDER = 'uploads/'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Define colors for bounding boxes (BGR format)
COLOR_HELMET = (0, 255, 0)         # Green for Helmet
COLOR_NO_HELMET = (0, 0, 255)      # Red for No Helmet
COLOR_LICENSE_PLATE = (255, 0, 0)  # Blue for License Plate
COLOR_TEXT = (0,255,0)       # White for text

# Route for video streaming with live YOLO detection
@app.route('/video_feed')
def video_feed():
    def generate_frames():
        cap = cv2.VideoCapture(0)  # Open camera feed
        if not cap.isOpened():
            return jsonify({'error': 'Camera not accessible'}), 500

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            # Perform YOLO inference on the frame
            results = model(frame)

            # Process detections
            for result in results[0].boxes.data:
                x1, y1, x2, y2 = map(int, result[:4])  # Bounding box coordinates
                class_id = int(result[5])  # Class ID

                # Set color and label based on class ID
                if class_id == 0:  # Helmet
                    color = COLOR_HELMET
                    label = 'Helmet'
                elif class_id == 1:  # License Plate
                    color = COLOR_LICENSE_PLATE
                    label = 'License Plate'
                else:  # No Helmet
                    color = COLOR_NO_HELMET
                    label = 'No Helmet'

                # Draw bounding box
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                # Add text label
                cv2.putText(frame, label, (x1, y1 - 10 if y1 > 20 else y1 + 20),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLOR_TEXT, 2)

            # Encode the frame as JPEG
            _, buffer = cv2.imencode('.jpg', frame)
            frame_data = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_data + b'\r\n')

        cap.release()

    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

# Helper function to upload images to Firebase Storage
def upload_image_to_firebase(img_path):
    blob = bucket.blob(os.path.basename(img_path))
    blob.upload_from_filename(img_path)
    blob.make_public()
    return blob.public_url

# Helper function to store bounding box data in Firestore
def store_bounding_box_data_in_firebase(detections, image_url):
    try:
        detection_data = {
            'image_url': image_url,
            'detections': detections
        }
        db.collection('Boundingboxes').add(detection_data)
        print('Detection data stored successfully.')
    except Exception as e:
        print(f'Error storing bounding box data: {e}')

# Modify the predict route to include OCR results for license plates
@app.route('/predict', methods=['POST'])
def predict():
    file = request.files.get('image')  # Get the image file from the request
    if not file:
        return jsonify({'error': 'No image uploaded'}), 400

    filename = file.filename
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    file.save(file_path)  # Save the uploaded image

    # Read the original image (color)
    original_img = cv2.imread(file_path)
    if original_img is None:
        return jsonify({'error': 'Failed to read image'}), 400

    # Convert to grayscale for processing
    gray_img = cv2.cvtColor(original_img, cv2.COLOR_BGR2GRAY)
    hist_equalized_img = cv2.equalizeHist(gray_img)  # Enhance contrast

    # Save the grayscale and histogram-equalized images for verification
    gray_img_path = os.path.join(UPLOAD_FOLDER, f"gray_{filename}")
    hist_img_path = os.path.join(UPLOAD_FOLDER, f"hist_{filename}")

    cv2.imwrite(gray_img_path, gray_img)  # Save grayscale image
    cv2.imwrite(hist_img_path, hist_equalized_img)  # Save histogram-equalized image

    # You can log or return these paths for debugging
    print(f"Grayscale image saved at: {gray_img_path}")
    print(f"Histogram-equalized image saved at: {hist_img_path}")

    # Use the grayscale image for YOLO inference
    results = model(cv2.cvtColor(hist_equalized_img, cv2.COLOR_GRAY2BGR))  # YOLO requires 3 channels

    # Process detections
    detections = []
    for result in results[0].boxes.data:
        x1, y1, x2, y2 = map(int, result[:4])  # Bounding box coordinates
        class_id = int(result[5])  # Class ID

        # Set color and label based on class ID
        if class_id == 0:  # Helmet
            color = COLOR_HELMET
            label = 'Helmet'
        elif class_id == 1:  # License Plate
            color = COLOR_LICENSE_PLATE
            label = 'License Plate'
        else:  # No Helmet
            color = COLOR_NO_HELMET
            label = 'No Helmet'

        # If it's a license plate, perform OCR
        license_text = ""
        if class_id == 1:  # License Plate class
            license_plate_img = hist_equalized_img[y1:y2, x1:x2]  # Crop from the grayscale image
            ocr_results = reader.readtext(license_plate_img)
            if ocr_results:
                for _, text, _ in ocr_results:
                    license_text += f"{text} "

            label += f": {license_text.strip()}"

        # Draw bounding boxes and labels on the original image
        cv2.rectangle(original_img, (x1, y1), (x2, y2), color, 2)
        # Adjust font scale and thickness
        font_scale = 0.9  # Smaller text size
        font_thickness = 3  # Normal thickness

        cv2.putText(original_img, label, 
                    (x1, y1 - 10 if y1 > 20 else y1 + 20), 
                    cv2.FONT_HERSHEY_SIMPLEX, 
                    font_scale, 
                    COLOR_TEXT, 
                    font_thickness)

        detections.append({
            'rect': {'x': x1, 'y': y1, 'w': x2 - x1, 'h': y2 - y1},
            'label': label,
            'license_text': license_text.strip() if class_id == 1 else ""
        })

    # Save the output image with bounding boxes drawn on the original image
    output_path = os.path.join(UPLOAD_FOLDER, f"output_{filename}")
    cv2.imwrite(output_path, original_img)

    # Upload to Firebase
    image_url = upload_image_to_firebase(output_path)

    # Store bounding box data in Firestore
    store_bounding_box_data_in_firebase(detections, image_url)

    return jsonify({
        'image_url': image_url,
        'detections': detections
    })

# Start Flask app
if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)

