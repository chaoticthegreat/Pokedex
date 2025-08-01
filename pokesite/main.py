import os
import torch
import torch.nn as nn
import torchvision.transforms as transforms
import torchaudio
import numpy as np
import cv2
import base64
from flask import Flask, request, render_template_string, jsonify, flash, redirect, url_for, Response
from werkzeug.utils import secure_filename
import tempfile
import librosa
from PIL import Image
import io
import threading
import time

app = Flask(__name__)
app.secret_key = 'your-secret-key-here'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Configure upload settings
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'flac', 'm4a', 'jpg', 'jpeg', 'png', 'bmp'}
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Global variables for webcam
camera = None
camera_active = False
latest_prediction = None
prediction_lock = threading.Lock()


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


# Audio CNN Model
class SimpleCNN(nn.Module):
    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv1 = nn.Conv2d(in_channels=1, out_channels=16, kernel_size=3, padding=1)
        self.batchNorm1 = nn.BatchNorm2d(16)
        self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv2 = nn.Conv2d(in_channels=16, out_channels=32, kernel_size=3, padding=1)
        self.batchNorm2 = nn.BatchNorm2d(32)
        self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv3 = nn.Conv2d(in_channels=32, out_channels=64, kernel_size=3, padding=1)
        self.batchNorm3 = nn.BatchNorm2d(64)
        self.pool3 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv4 = nn.Conv2d(in_channels=64, out_channels=128, kernel_size=3, padding=1)
        self.batchNorm4 = nn.BatchNorm2d(128)

        self.fc1 = nn.Linear(128 * 8 * 25, 512)
        self.fc2 = nn.Linear(512, 256)
        self.dropout = nn.Dropout(0.1)
        self.fc3 = nn.Linear(256, 8)

    def forward(self, x):
        x = torch.relu(self.batchNorm1(self.conv1(x)))
        x = self.pool1(x)
        x = torch.relu(self.batchNorm2(self.conv2(x)))
        x = self.pool2(x)
        x = torch.relu(self.batchNorm3(self.conv3(x)))
        x = self.pool3(x)
        x = torch.relu(self.batchNorm4(self.conv4(x)))
        x = x.view(-1, 128 * 8 * 25)
        x = torch.relu(self.fc1(x))
        x = self.dropout(x)
        x = torch.relu(self.fc2(x))
        x = self.dropout(x)
        x = self.fc3(x)
        return x


# Image CNN Model (Simple example - replace with your actual model)

class ImageCNN(nn.Module):
  def __init__(self):
    super(ImageCNN, self).__init__()
    self.conv1 = nn.Conv2d(in_channels=3, out_channels=16, kernel_size=3, padding=1)
    self.batchNorm1 = nn.BatchNorm2d(16)
    self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)


    self.conv2 = nn.Conv2d(in_channels=16, out_channels=32, kernel_size=3, padding=1)
    self.batchNorm2 = nn.BatchNorm2d(32)
    self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)

    self.conv3 = nn.Conv2d(in_channels=32, out_channels=64, kernel_size=3, padding=1)
    self.batchNorm3 = nn.BatchNorm2d(64)
    self.pool3 = nn.MaxPool2d(kernel_size=2, stride=2)

    self.conv4 = nn.Conv2d(in_channels=64, out_channels=128, kernel_size=3, padding=1)
    self.batchNorm4 = nn.BatchNorm2d(128)
    self.pool4 = nn.MaxPool2d(kernel_size=2, stride=2)

    self.fc1 = nn.Linear(18432, 256)
    self.dropout = nn.Dropout(0.5)
    self.fc2 = nn.Linear(256, 8)
  def forward(self, x):
    x = torch.relu(self.batchNorm1(self.conv1(x)))

    x = self.pool1(x)

    x = torch.relu(self.batchNorm2(self.conv2(x)))
    x = self.pool2(x)

    x = torch.relu(self.batchNorm3(self.conv3(x)))
    x = self.pool3(x)

    x = torch.relu(self.batchNorm4(self.conv4(x)))
    x = self.pool4(x)


    x = x.view(-1, 18432)

    x = torch.relu(self.fc1(x))
    x = self.dropout(x)
    x = self.fc2(x)
    return x


# Initialize models
audio_model = SimpleCNN()
image_model = ImageCNN()  # Adjust num_classes as needed

# Load audio model
try:
    audio_model.load_state_dict(torch.load("./model.pth", map_location=torch.device('cpu')))
    audio_model.eval()
    print("✅ Audio model loaded successfully")
except:
    print("⚠️ Audio model not found - audio predictions will not work")

# Load image model (create a dummy one if file doesn't exist)
try:
    image_model.load_state_dict(torch.load("./image_model.pth", map_location=torch.device('cpu')))
    image_model.eval()
    print("✅ Image model loaded successfully")
except:
    print("⚠️ Image model not found - using dummy model for demonstration")

# Class labels
AUDIO_CLASS_LABELS = [
    'bulbosaur', 'charmander', 'gengar', 'magikarp', 'mew', 'pikachu', 'psyduck', 'squirtle'
]

IMAGE_CLASS_LABELS = [
    'bulbosaur', 'charmander', 'gengar', 'magikarp', 'mew', 'pikachu', 'psyduck', 'squirtle'
]

# Image preprocessing
image_transform = transforms.Compose([
    transforms.Resize((200, 200)),
    transforms.ToTensor(),
    # transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])


def load_audio(file_path, target_sr=16000, duration=100):
    """Load and preprocess audio file"""
    try:
        audio, sr = librosa.load(file_path, sr=target_sr, duration=duration)
        return torch.tensor(audio, dtype=torch.float32), sr
    except Exception as e:
        print(f"Error loading audio with librosa: {e}")
        try:
            audio, sr = torchaudio.load(file_path)
            if sr != target_sr:
                resampler = torchaudio.transforms.Resample(sr, target_sr)
                audio = resampler(audio)
            if audio.shape[0] > 1:
                audio = torch.mean(audio, dim=0, keepdim=True)
            return audio.squeeze(), target_sr
        except Exception as e2:
            raise Exception(f"Failed to load audio: {e2}")


def audio_to_mel_spectrogram(audio, sr=16000, n_mels=64, n_fft=400, hop_length=200):
    """Convert audio to mel spectrogram"""
    if len(audio.shape) > 1:
        audio = audio.squeeze()

    mel_transform = torchaudio.transforms.MelSpectrogram(
        sample_rate=sr,
        n_mels=n_mels,
        n_fft=n_fft,
        hop_length=hop_length,
        power=2.0
    )

    mel_spec = mel_transform(audio)
    mel_spec_db = torchaudio.transforms.AmplitudeToDB()(mel_spec)

    if mel_spec_db.shape[-1] < 200:
        padding = 200 - mel_spec_db.shape[-1]
        mel_spec_db = torch.nn.functional.pad(mel_spec_db, (0, padding))
    elif mel_spec_db.shape[-1] > 200:
        mel_spec_db = mel_spec_db[:, :, :200]

    return mel_spec_db


def predict_audio(file_path):
    """Perform inference on audio file"""
    try:
        audio, sr = load_audio(file_path)
        mel_spec = audio_to_mel_spectrogram(audio, sr)

        if mel_spec.shape[-1] < 200:
            padding = 200 - mel_spec.shape[-1]
            waveform = torch.nn.functional.pad(mel_spec, (0, padding))
        elif mel_spec.shape[-1] > 200:
            # print(waveform.shape[-1])
            waveform = mel_spec[:, :, :200]

        mel_spec = mel_spec.unsqueeze(0).unsqueeze(0)

        with torch.no_grad():
            outputs = audio_model(mel_spec)
            probabilities = torch.softmax(outputs, dim=1)
            predicted_class = torch.argmax(probabilities, dim=1).item()
            confidence = probabilities[0][predicted_class].item()

        return {
            'predicted_class': AUDIO_CLASS_LABELS[predicted_class],
            'confidence': float(confidence),
            'all_probabilities': {AUDIO_CLASS_LABELS[i]: float(prob) for i, prob in enumerate(probabilities[0])},
            'mel_spec_shape': list(mel_spec.shape)
        }

    except Exception as e:
        return {'error': str(e)}


def predict_image(image):
    """Perform inference on image"""
    try:
        # Preprocess image
        if isinstance(image, np.ndarray):
            # Convert from BGR to RGB if it's from OpenCV
            if len(image.shape) == 3 and image.shape[2] == 3:
                image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            image = Image.fromarray(image)

        # Apply transforms
        image_tensor = image_transform(image).unsqueeze(0)

        with torch.no_grad():
            outputs = image_model(image_tensor)
            probabilities = torch.softmax(outputs, dim=1)
            predicted_class = torch.argmax(probabilities, dim=1).item()
            confidence = probabilities[0][predicted_class].item()

        return {
            'predicted_class': IMAGE_CLASS_LABELS[predicted_class],
            'confidence': float(confidence),
            'all_probabilities': {IMAGE_CLASS_LABELS[i]: float(prob) for i, prob in enumerate(probabilities[0])}
        }

    except Exception as e:
        return {'error': str(e)}


def process_webcam_frame():
    """Process webcam frames continuously"""
    global camera, camera_active, latest_prediction

    while camera_active:
        if camera is not None:
            ret, frame = camera.read()
            if ret:
                # Run prediction every few frames to avoid overload
                prediction = predict_image(frame)

                with prediction_lock:
                    latest_prediction = prediction

                time.sleep(0.1)  # Process ~10 FPS for predictions
        time.sleep(0.01)


def generate_frames():
    """Generate frames for video streaming"""
    global camera, latest_prediction

    while camera_active:
        if camera is not None:
            success, frame = camera.read()
            if not success:
                break
            else:
                # Add prediction overlay
                with prediction_lock:
                    if latest_prediction and 'predicted_class' in latest_prediction:
                        class_name = latest_prediction['predicted_class']
                        confidence = latest_prediction['confidence']

                        # Draw prediction on frame
                        cv2.rectangle(frame, (10, 10), (400, 80), (0, 0, 0), -1)
                        cv2.putText(frame, f"Class: {class_name}", (20, 35),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                        cv2.putText(frame, f"Confidence: {confidence:.2%}", (20, 60),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

                ret, buffer = cv2.imencode('.jpg', frame)
                frame = buffer.tobytes()
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')


# HTML template with webcam support
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audio & Image ML Inference</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .tabs {
            display: flex;
            border-bottom: 2px solid #eee;
            margin-bottom: 20px;
        }
        .tab {
            padding: 10px 20px;
            cursor: pointer;
            border: none;
            background: none;
            font-size: 16px;
            border-bottom: 3px solid transparent;
        }
        .tab.active {
            border-bottom-color: #007bff;
            color: #007bff;
            font-weight: bold;
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
        .upload-area {
            border: 2px dashed #ccc;
            border-radius: 10px;
            padding: 40px;
            text-align: center;
            margin: 20px 0;
            transition: border-color 0.3s;
        }
        .upload-area:hover {
            border-color: #007bff;
        }
        .btn {
            background-color: #007bff;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
            margin: 5px;
        }
        .btn:hover {
            background-color: #0056b3;
        }
        .btn-success {
            background-color: #28a745;
        }
        .btn-danger {
            background-color: #dc3545;
        }
        .webcam-container {
            text-align: center;
            margin: 20px 0;
        }
        .webcam-feed {
            border: 2px solid #ccc;
            border-radius: 10px;
            max-width: 100%;
            height: auto;
        }
        .prediction-display {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
        .results {
            margin-top: 30px;
            padding: 20px;
            background-color: #f8f9fa;
            border-radius: 8px;
        }
        .error {
            color: #dc3545;
            background-color: #f8d7da;
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        .success {
            color: #155724;
            background-color: #d4edda;
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        .prob-bar {
            background-color: #e9ecef;
            height: 20px;
            border-radius: 10px;
            margin: 5px 0;
            overflow: hidden;
        }
        .prob-fill {
            background-color: #007bff;
            height: 100%;
            transition: width 0.3s;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Pokedex</h1>
        <p>Upload audio files or use your webcam for real-time image classification.</p>

        <div class="tabs">
            <button class="tab active" onclick="switchTab('audio')">Audio Analysis</button>
            <button class="tab" onclick="switchTab('webcam')">Live Webcam</button>
            <button class="tab" onclick="switchTab('image')">Image Upload</button>
        </div>

        <!-- Audio Tab -->
        <div id="audio" class="tab-content active">
            {% with messages = get_flashed_messages() %}
                {% if messages %}
                    {% for message in messages %}
                        <div class="error">{{ message }}</div>
                    {% endfor %}
                {% endif %}
            {% endwith %}

            <form method="POST" enctype="multipart/form-data">
                <div class="upload-area">
                    <input type="file" name="audio_file" accept=".wav,.mp3,.flac,.m4a" style="margin-bottom: 20px;">
                    <br>
                    <button type="submit" class="btn">Analyze Audio</button>
                </div>
            </form>

            {% if audio_results %}
            <div class="results">
                {% if audio_results.error %}
                    <div class="error">
                        <strong>Error:</strong> {{ audio_results.error }}
                    </div>
                {% else %}
                    <div class="success">
                        <h3>Audio Prediction Results</h3>
                        <p><strong>Predicted Class:</strong> {{ audio_results.predicted_class }}</p>
                        <p><strong>Confidence:</strong> {{ "%.2f"|format(audio_results.confidence * 100) }}%</p>
                    </div>
                {% endif %}
            </div>
            {% endif %}
        </div>

        <!-- Webcam Tab -->
        <div id="webcam" class="tab-content">
            <div class="webcam-container">
                <h3>Live Webcam Classification</h3>
                <div>
                    <button id="startBtn" class="btn btn-success" onclick="startWebcam()">▶️ Start Camera</button>
                    <button id="stopBtn" class="btn btn-danger" onclick="stopWebcam()" style="display:none;">⏹️ Stop Camera</button>
                </div>
                <div id="webcamFeed" style="display:none; margin-top: 20px;">
                    <img id="videoFeed" class="webcam-feed" src="/video_feed" alt="Webcam Feed">
                </div>
                <div id="livePrediction" class="prediction-display" style="display:none;">
                    <h4>Live Predictions</h4>
                    <div id="predictionContent">Waiting for predictions...</div>
                </div>
            </div>
        </div>

        <!-- Image Upload Tab -->
        <div id="image" class="tab-content">
            <form method="POST" enctype="multipart/form-data">
                <div class="upload-area">
                    <input type="file" name="image_file" accept=".jpg,.jpeg,.png,.bmp" style="margin-bottom: 20px;">
                    <br>
                    <button type="submit" class="btn">Analyze Image</button>
                </div>
            </form>

            {% if image_results %}
            <div class="results">
                {% if image_results.error %}
                    <div class="error">
                        <strong>Error:</strong> {{ image_results.error }}
                    </div>
                {% else %}
                    <div class="success">
                        <h3>Image Prediction Results</h3>
                        <p><strong>Predicted Class:</strong> {{ image_results.predicted_class }}</p>
                        <p><strong>Confidence:</strong> {{ "%.2f"|format(image_results.confidence * 100) }}%</p>
                    </div>
                {% endif %}
            </div>
            {% endif %}
        </div>
    </div>

    <script>
        function switchTab(tabName) {
            // Hide all tab contents
            document.querySelectorAll('.tab-content').forEach(content => {
                content.classList.remove('active');
            });

            // Remove active class from all tabs
            document.querySelectorAll('.tab').forEach(tab => {
                tab.classList.remove('active');
            });

            // Show selected tab content
            document.getElementById(tabName).classList.add('active');

            // Add active class to clicked tab
            event.target.classList.add('active');
        }

        function startWebcam() {
            fetch('/start_webcam', {method: 'POST'})
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('startBtn').style.display = 'none';
                        document.getElementById('stopBtn').style.display = 'inline-block';
                        document.getElementById('webcamFeed').style.display = 'block';
                        document.getElementById('livePrediction').style.display = 'block';

                        // Start polling for predictions
                        startPredictionPolling();
                    }
                });
        }

        function stopWebcam() {
            fetch('/stop_webcam', {method: 'POST'})
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('startBtn').style.display = 'inline-block';
                        document.getElementById('stopBtn').style.display = 'none';
                        document.getElementById('webcamFeed').style.display = 'none';
                        document.getElementById('livePrediction').style.display = 'none';

                        // Stop polling
                        stopPredictionPolling();
                    }
                });
        }

        let predictionInterval;

        function startPredictionPolling() {
            predictionInterval = setInterval(() => {
                fetch('/get_prediction')
                    .then(response => response.json())
                    .then(data => {
                        if (data.predicted_class) {
                            document.getElementById('predictionContent').innerHTML = `
                                <p><strong>Class:</strong> ${data.predicted_class}</p>
                                <p><strong>Confidence:</strong> ${(data.confidence * 100).toFixed(1)}%</p>
                            `;
                        }
                    })
                    .catch(err => console.error('Prediction polling error:', err));
            }, 500); // Update every 500ms
        }

        function stopPredictionPolling() {
            if (predictionInterval) {
                clearInterval(predictionInterval);
            }
        }
    </script>
</body>
</html>
"""


@app.route('/', methods=['GET', 'POST'])
def upload_file():
    audio_results = None
    image_results = None

    if request.method == 'POST':
        # Handle audio file upload
        if 'audio_file' in request.files and request.files['audio_file'].filename:
            file = request.files['audio_file']
            if file and allowed_file(file.filename):
                filename = secure_filename(file.filename)
                with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp_file:
                    file.save(tmp_file.name)
                    try:
                        audio_results = predict_audio(tmp_file.name)
                    finally:
                        os.unlink(tmp_file.name)

        # Handle image file upload
        if 'image_file' in request.files and request.files['image_file'].filename:
            file = request.files['image_file']
            if file and allowed_file(file.filename):
                image = Image.open(file.stream)
                image_results = predict_image(image)

    return render_template_string(HTML_TEMPLATE,
                                  audio_results=audio_results,
                                  image_results=image_results,
                                  audio_class_labels=AUDIO_CLASS_LABELS,
                                  image_class_labels=IMAGE_CLASS_LABELS)


@app.route('/start_webcam', methods=['POST'])
def start_webcam():
    global camera, camera_active
    try:
        camera = cv2.VideoCapture(0)
        if not camera.isOpened():
            return jsonify({'success': False, 'error': 'Could not open camera'})

        camera_active = True

        # Start prediction thread
        prediction_thread = threading.Thread(target=process_webcam_frame)
        prediction_thread.daemon = True
        prediction_thread.start()

        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/stop_webcam', methods=['POST'])
def stop_webcam():
    global camera, camera_active
    try:
        camera_active = False
        if camera:
            camera.release()
            camera = None
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/video_feed')
def video_feed():
    return Response(generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/get_prediction')
def get_prediction():
    global latest_prediction
    with prediction_lock:
        if latest_prediction:
            return jsonify(latest_prediction)
        else:
            return jsonify({'predicted_class': None})


@app.route('/api/predict', methods=['POST'])
def api_predict():
    """API endpoint for programmatic access"""
    results = {}

    # Handle audio prediction
    if 'audio_file' in request.files:
        file = request.files['audio_file']
        if allowed_file(file.filename):
            with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp_file:
                file.save(tmp_file.name)
                try:
                    results['audio'] = predict_audio(tmp_file.name)
                finally:
                    os.unlink(tmp_file.name)

    # Handle image prediction
    if 'image_file' in request.files:
        file = request.files['image_file']
        if allowed_file(file.filename):
            image = Image.open(file.stream)
            results['image'] = predict_image(image)

    if not results:
        return jsonify({'error': 'No valid files provided'}), 400

    return jsonify(results)


if __name__ == '__main__':
    print("Web interface: http://localhost:8080")
    print("API endpoint: http://localhost:8080/api/predict")


    # Cleanup function
    def cleanup():
        global camera, camera_active
        camera_active = False
        if camera:
            camera.release()


    import atexit

    atexit.register(cleanup)

    app.run(debug=True, host='0.0.0.0', port=8080)