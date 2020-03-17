import SSD1331
import datetime
import time
import math
import pdb
import json
import commands

SSD1331_PIN_CS  = 8
SSD1331_PIN_DC  = 23
SSD1331_PIN_RST = 24

COLOR_GREY        =  SSD1331.Color656(40, 40, 40)
COLOR_DARK_GREEN  =  SSD1331.Color656( 0, 40, 0)
COLOR_DARK_RED    =  SSD1331.Color656( 0, 40, 0)
COLOR_DARK_YELLOW =  SSD1331.Color656(40, 40, 0)
COLOR_DARK_GOLDEN =  SSD1331.Color656(40, 20, 0)

color_schema = {
    "day": {
        "datetime": SSD1331.COLOR_WHITE,
        "co2_low": SSD1331.COLOR_GREEN,
        "co2_medium": SSD1331.COLOR_YELLOW,
        "co2_high": SSD1331.COLOR_RED,
        "humidity": SSD1331.COLOR_WHITE,
        "pressure": SSD1331.COLOR_WHITE,
        "temperature": SSD1331.COLOR_GREEN,
        "ip_address": SSD1331.COLOR_GOLDEN
    },
    "night": {
        "datetime": COLOR_GREY,
        "co2_low": COLOR_DARK_GREEN,
        "co2_medium": COLOR_DARK_YELLOW,
        "co2_high": COLOR_DARK_RED,
        "humidity": COLOR_GREY,
        "pressure": COLOR_GREY,
        "temperature": COLOR_DARK_GREEN,
        "ip_address": COLOR_DARK_GOLDEN
    }
}

if __name__ == '__main__':
    device = SSD1331.SSD1331(SSD1331_PIN_DC, SSD1331_PIN_RST, SSD1331_PIN_CS)
    data_loaded = False

    try:
        device.EnableDisplay(True)
        device.Clear()

        while True:
            my_now = datetime.datetime.now()
            schema_name = "day" if 8 < my_now.hour < 23 else "night"
            schema = color_schema[schema_name]

            device.DrawStringBg(0, 0, my_now.strftime("%Y-%m-%d %H:%M"), schema["datetime"])

            ip_address = commands.getoutput('hostname -I')
            device.DrawStringBg(0, 55, ip_address, schema["ip_address"])

            if not data_loaded:
              device.DrawStringBg(0, 25, "Waiting for data", schema["datetime"])

            with open("schnozer.out.json", "r") as data_file:
                if not data_loaded:
                  device.Clear()

                data = json.loads(data_file.readlines()[-1])
                data_loaded = True

            for line in data:
                if line['series'] == 'mh_z19b_f':
                    ppm = line['concentration']
                    ppm_control = '{:>4} ppm'.format(ppm)
                    ppm_color = (ppm < 900 and schema["co2_low"]) or (ppm < 1500 and schema["co2_medium"]) or schema["co2_high"]

                    device.DrawStringBg(0, 15, ppm_control, ppm_color)
                else:
                    temp_control = '{:+04.2f} C'.format(line['temperature'])
                    device.DrawStringBg(0, 25, temp_control, schema["temperature"])

                    humidity_control = '{:4d} %H'.format(int(line['humidity']))
                    device.DrawStringBg(54, 15, humidity_control, schema["humidity"])

                    pressure_control = '{:4d}hPa'.format(int(line['pressure']))
                    device.DrawStringBg(54, 25, pressure_control, schema["pressure"])
    finally:
        device.EnableDisplay(False)
        device.Remove()
