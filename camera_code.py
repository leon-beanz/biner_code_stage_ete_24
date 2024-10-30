from picamera2 import Picamera2, Preview
import RPi.GPIO as GPIO

GPIO.setmode(GPIO.BOARD)
GPIO.setup(10, GPIO.IN)
GPIO.setup(8, GPIO.OUT)
GPIO.output(8, GPIO.LOW)

i = 0

while True:
	if GPIO.input(10) is GPIO.HIGH:
		GPIO.output(8, GPIO.HIGH)
		camera = Picamera2()
		camera.start_and_record_video(f"videos/video{i}.mp4", duration=5, show_preview=True)
		camera.close()
		GPIO.output(8, GPIO.LOW)
		i += 1
	else:
		GPIO.output(8, GPIO.LOW)
