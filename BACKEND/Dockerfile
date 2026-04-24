# Use Python as the base
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy the backend code
COPY app.py .

# Install Flask
RUN pip install flask

# Expose the port Flask runs on
EXPOSE 5000

# Start the app
CMD ["python", "app.py"]
