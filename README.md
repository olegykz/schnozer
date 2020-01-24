# Schnozer :nose:
Raspberry-PI-based solution to analyze the air quality (CO2, temperature, humidity, pressure)

# How it works :gear:
* For humidity, temperature and pressure data I'm using BME280 sensor
* CO2 :biohazard: concentration data is provided by MH-Z19B sensor 

# Data utilization :bar_chart:
Obtained values are reported to shared influxDb instance (https://www.influxdata.com/)

# Credits :clap:
* BME280 code is based on https://github.com/kochka/ruby_rpi_components
* MH-Z19B code is based on https://github.com/cho45/ruby-mh-z19
