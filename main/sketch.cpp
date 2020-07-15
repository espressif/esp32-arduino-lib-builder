#include "Arduino.h"
//#include "esp_rmaker_core.h"
#include <esp_rmaker_standard_params.h>
#include "esp_camera.h"
void setup(){
    /*esp_rmaker_config_t rainmaker_cfg = {
         .info = { 
             .name = "Device",
             .type = "switch",
         },
         .enable_time_sync = false,
     };
     esp_err_t err = esp_rmaker_init(&rainmaker_cfg);*/
    esp_rmaker_device_add_name_param("Switch","name");
    esp_camera_deinit();

}

void loop(){
  
}
