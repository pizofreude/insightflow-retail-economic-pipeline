# Dockerfile for the InsightFlow Ingestion Script

# 1. Base Image: Use an official Python runtime as a parent image.
# Using a slim version reduces the final image size.
# Choose a version consistent with your development environment (e.g., 3.10, 3.11, 3.12)
FROM python:3.11-slim

# 2. Set Working Directory: Define the working directory inside the container.
WORKDIR /app

# 3. Copy Requirements File: Copy the dependencies file first.
# This leverages Docker layer caching - dependencies are only re-installed if requirements.txt changes.
COPY requirements.txt .

# 4. Install Dependencies: Install Python packages listed in requirements.txt.
# --no-cache-dir reduces image size by not storing the pip cache.
# --upgrade pip ensures the latest pip version is used.
RUN pip install --no-cache-dir --upgrade pip -r requirements.txt

# 5. Copy Application Code: Copy the main script into the working directory.
# If you had other modules/files in src/ingestion/, you could copy the whole directory: COPY . .
COPY main.py .

# 6. Set Environment Variable for Unbuffered Output (Good practice for logging)
ENV PYTHONUNBUFFERED=1

# 7. Define Default Command: Specify the command to run when the container starts.
# AWS Batch will execute this command to run your ingestion script.
CMD ["python", "main.py"]
