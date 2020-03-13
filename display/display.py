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

if __name__ == '__main__':
    device = SSD1331.SSD1331(SSD1331_PIN_DC, SSD1331_PIN_RST, SSD1331_PIN_CS)
    try:
        device.EnableDisplay(True)
        device.Clear()
        while True:
            my_now = datetime.datetime.now()
            device.DrawStringBg(0, 0, my_now.strftime("%Y-%m-%d %H:%M"), SSD1331.COLOR_WHITE, SSD1331.COLOR_BLACK)

	    data = ""
            with open("sniff.json", "r") as data_file:
            	data = json.loads(data_file.readlines()[-1])

            if data == "":
              sleep(1)
              continue

            for line in data:
              if line['series'] == 'mh_z19b':
                ppm = line['values']['concentration']
                ppm_control = '{:>4} ppm'.format(ppm)
                ppm_color = (ppm < 900 and SSD1331.COLOR_GREEN) or (ppm < 1500 and SSD1331.COLOR_YELLOW) or SSD1331.COLOR_RED
 
                device.DrawStringBg(0, 15, ppm_control, ppm_color, SSD1331.COLOR_BLACK)
              else:
                temp_control = '{:+04.2f} C'.format(line['values']['temperature'])
                device.DrawStringBg(0, 25, temp_control, SSD1331.COLOR_GREEN, SSD1331.COLOR_BLACK)

                humidity_control = '{:4d} %H'.format(int(line['values']['humidity']))
                device.DrawStringBg(54, 15, humidity_control, SSD1331.COLOR_WHITE, SSD1331.COLOR_BLACK)

		pressure_control = '{:4d}hPa'.format(int(line['values']['pressure']))
                device.DrawStringBg(54, 25, pressure_control, SSD1331.COLOR_WHITE, SSD1331.COLOR_BLACK)

                wifi_control = commands.getoutput('hostname -I')
                device.DrawStringBg(0, 55, wifi_control, SSD1331.COLOR_GOLDEN, SSD1331.COLOR_BLACK)
            time.sleep(3)
    finally:
        device.EnableDisplay(False)
        device.Remove()
