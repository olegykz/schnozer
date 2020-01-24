# Schnozer (WIP)
Raspberry-PI-based solution to analyze the air quiality (CO2, temperature, humidity, pressure)

# How it works
* For humidity, temperature and pressure data I'm using BME280 sensor
* CO2 concentration data is provided by MH-Z19B sensor 

# Data utilization
Obtained values are reported to shared influxDb instance (https://www.influxdata.com/)
