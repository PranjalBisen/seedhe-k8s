# Use the official Python image as the base image.
FROM python:3.12-slim

# Run the app from /app inside the container.
WORKDIR /app

# Copy our Python application into the image.
COPY app.py .

# Document that the application listens on port 8080.
EXPOSE 8080

# Start the Python HTTP server when the container starts.
CMD ["python", "app.py"]
