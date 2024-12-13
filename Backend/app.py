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

@app.route('/camera_feed', methods=['GET'])
def camera_feed():
    cap = cv2.VideoCapture(0)  # 0 is the default camera
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    if not cap.isOpened():
        return jsonify({'error': 'Camera not accessible'}), 500

    while True:
        ret, frame = cap.read()
        if not ret:
            return jsonify({'error': 'Failed to capture frame'}), 500

        # Perform YOLO inference on the frame
        results = model(frame)

        # Process detections
        detections = []
        for result in results[0].boxes.data:
            x1, y1, x2, y2 = map(int, result[:4])  # Bounding box coordinates
            class_id = int(result[5])  # Class ID

            label = 'Helmet' if class_id == 0 else ('License Plate' if class_id == 1 else 'No Helmet')
            detections.append({
                'rect': {'x': x1, 'y': y1, 'w': x2 - x1, 'h': y2 - y1},
                'label': label
            })

            # Draw bounding boxes and labels on the frame
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(frame, label, (x1, y1 - 10 if y1 > 20 else y1 + 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

        # Convert the frame to JPEG format
        _, jpeg = cv2.imencode('.jpg', frame)
        frame_data = jpeg.tobytes()

        # Return the frame as a response
        return (frame_data, 200, {'Content-Type': 'image/jpeg'})

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

            for result in results[0].boxes.data:
                x1, y1, x2, y2 = map(int, result[:4])  # Bounding box coordinates
                class_id = int(result[5])  # Class ID
                label = 'Helmet' if class_id == 0 else ('License Plate' if class_id == 1 else 'No Helmet')
                
                # Draw bounding boxes
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(frame, label, (x1, y1 - 10 if y1 > 20 else y1 + 20),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

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

    img = cv2.imread(file_path)
    if img is None:
        return jsonify({'error': 'Failed to read image'}), 400

    # Resize the image for consistent processing
    max_width = 800
    height, width, _ = img.shape
    if width > max_width:
        aspect_ratio = height / width
        new_width = max_width
        new_height = int(aspect_ratio * new_width)
        img = cv2.resize(img, (new_width, new_height))

    # Perform YOLO inference
    results = model(img)

    # Process detections
    detections = []
    license_plates_seen = set()  # Set to track seen license plates
    for result in results[0].boxes.data:
        x1, y1, x2, y2 = map(int, result[:4])  # Bounding box coordinates
        class_id = int(result[5])  # Class ID

        label = 'Helmet' if class_id == 0 else ('License Plate' if class_id == 1 else 'No Helmet')

        # Process License Plate OCR
        if class_id == 1:  # License Plate class
            license_plate_img = img[y1:y2, x1:x2]
            ocr_results = reader.readtext(license_plate_img)

            license_text = ""
            if ocr_results:
                for _, text, ocr_conf in ocr_results:
                    if text not in license_plates_seen:  # Avoid duplicate OCR results
                        license_text += f"{text} "
                        license_plates_seen.add(text)
                        print(f'OCR Result: {text}, Confidence: {ocr_conf:.2f}')

            label += f": {license_text.strip()}"

        # Draw bounding boxes and labels
        cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(img, label, (x1, y1 - 10 if y1 > 20 else y1 + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

        detections.append({
            'rect': {'x': x1, 'y': y1, 'w': x2 - x1, 'h': y2 - y1},
            'label': label,
            'license_text': license_text.strip() if class_id == 1 else ""  # Add license text here
        })

    # Save the output image with bounding boxes
    output_path = os.path.join(UPLOAD_FOLDER, f"output_{filename}")
    cv2.imwrite(output_path, img)

    # Upload the image to Firebase Storage
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