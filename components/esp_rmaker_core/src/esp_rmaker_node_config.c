// Copyright 2020 Espressif Systems (Shanghai) PTE LTD
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#include <sdkconfig.h>
#include <string.h>
#include <esp_log.h>
#include <json_generator.h>
#include <esp_rmaker_core.h>
#include "esp_rmaker_internal.h"
#include "esp_rmaker_mqtt.h"

#define NODE_CONFIG_TOPIC_SUFFIX        "config"
#define MAX_NODE_CONFIG_SIZE            CONFIG_ESP_RMAKER_MAX_NODE_CONFIG_SIZE

static const char *TAG = "esp_rmaker_node_config";
static esp_err_t esp_rmaker_report_info(json_gen_str_t *jptr)
{
    /* TODO: Error handling */
    esp_rmaker_node_info_t *info = esp_rmaker_get_node_info();
    json_gen_obj_set_string(jptr, "node_id", esp_rmaker_get_node_id());
    json_gen_obj_set_string(jptr, "config_version", ESP_RMAKER_CONFIG_VERSION);
    json_gen_push_object(jptr, "info");
    json_gen_obj_set_string(jptr, "name",  info->name);
    json_gen_obj_set_string(jptr, "fw_version",  info->fw_version);
    json_gen_obj_set_string(jptr, "type",  info->type);
    json_gen_obj_set_string(jptr, "model",  info->model);
    json_gen_pop_object(jptr);
    return ESP_OK;
}

static void esp_rmaker_report_attribute(esp_rmaker_attr_t *attr, json_gen_str_t *jptr)
{
    json_gen_start_object(jptr);
    json_gen_obj_set_string(jptr, "name", attr->name);
    json_gen_obj_set_string(jptr, "value", attr->value);
    json_gen_end_object(jptr);
}

static esp_err_t esp_rmaker_report_node_attributes(json_gen_str_t *jptr)
{
    esp_rmaker_attr_t *attr = esp_rmaker_get_first_node_attribute();
    if (!attr) {
        return ESP_OK;
    }
    json_gen_push_array(jptr, "attributes");
    while (attr) {
        esp_rmaker_report_attribute(attr, jptr);
        attr = attr->next;
    }
    json_gen_pop_array(jptr);
    return ESP_OK;
}

static esp_err_t esp_rmaker_report_device_templates(json_gen_str_t *jptr)
{
    return ESP_OK;
}
static esp_err_t esp_rmaker_report_param_templates(json_gen_str_t *jptr)
{
    return ESP_OK;
}
static esp_err_t esp_rmaker_report_templates(json_gen_str_t *jptr)
{
    if ((esp_rmaker_get_first_device_template() != NULL ) ||
            (esp_rmaker_get_first_param_template() != NULL)) {
        json_gen_push_object(jptr, "templates");
        esp_rmaker_report_param_templates(jptr);
        esp_rmaker_report_device_templates(jptr);
        json_gen_pop_object(jptr);
    }
    return ESP_OK;
}
esp_err_t esp_rmaker_report_value(esp_rmaker_param_val_t *val, char *key, json_gen_str_t *jptr)
{
    if (!key || !jptr) {
        return ESP_FAIL;
    }
    if (!val) {
        json_gen_obj_set_null(jptr, key);
        return ESP_OK;
    }
    switch (val->type) {
        case RMAKER_VAL_TYPE_BOOLEAN:
            json_gen_obj_set_bool(jptr, key, val->val.b);
            break;
        case RMAKER_VAL_TYPE_INTEGER:
            json_gen_obj_set_int(jptr, key, val->val.i);
            break;
        case RMAKER_VAL_TYPE_FLOAT:
            json_gen_obj_set_float(jptr, key, val->val.f);
            break;
        case RMAKER_VAL_TYPE_STRING:
            json_gen_obj_set_string(jptr, key, val->val.s);
            break;
        default:
            break;
    }
    return ESP_OK;
}

esp_err_t esp_rmaker_report_data_type(esp_rmaker_val_type_t type, json_gen_str_t *jptr)
{
    switch (type) {
        case RMAKER_VAL_TYPE_BOOLEAN:
            json_gen_obj_set_string(jptr, "data_type", "bool");
            break;
        case RMAKER_VAL_TYPE_INTEGER:
            json_gen_obj_set_string(jptr, "data_type", "int");
            break;
        case RMAKER_VAL_TYPE_FLOAT:
            json_gen_obj_set_string(jptr, "data_type", "float");
            break;
        case RMAKER_VAL_TYPE_STRING:
            json_gen_obj_set_string(jptr, "data_type", "string");
            break;
        default:
            json_gen_obj_set_string(jptr, "data_type", "invalid");
            break;
    }
    return ESP_OK;
}

static esp_err_t esp_rmaker_report_param_config(esp_rmaker_param_t *param, json_gen_str_t *jptr)
{
    json_gen_start_object(jptr);
    if (param->name) {
        json_gen_obj_set_string(jptr, "name", param->name);
    }
    if (param->type) {
        json_gen_obj_set_string(jptr, "type", param->type);
    }
    esp_rmaker_report_data_type(param->val.type, jptr);
    json_gen_push_array(jptr, "properties");
    if (param->prop_flags & PROP_FLAG_READ) {
        json_gen_arr_set_string(jptr, "read");
    }
    if (param->prop_flags & PROP_FLAG_WRITE) {
        json_gen_arr_set_string(jptr, "write");
    }
    if (param->prop_flags & PROP_FLAG_TIME_SERIES) {
        json_gen_arr_set_string(jptr, "time_series");
    }
    json_gen_pop_array(jptr);
    if ((param->min.type != RMAKER_VAL_TYPE_INVALID) || (param->max.type != RMAKER_VAL_TYPE_INVALID)) {
        json_gen_push_object(jptr, "bounds");
        esp_rmaker_report_value(&param->min, "min", jptr);
        esp_rmaker_report_value(&param->max, "max", jptr);
        if (param->step.val.i) {
            esp_rmaker_report_value(&param->step, "step", jptr);
        }
        json_gen_pop_object(jptr);

    }
    if (param->ui_type) {
        json_gen_obj_set_string(jptr, "ui_type", param->ui_type);
    }
    json_gen_end_object(jptr);
    return ESP_OK;
}

static esp_err_t esp_rmaker_report_devices_or_services(json_gen_str_t *jptr, char *key)
{
    esp_rmaker_device_t *device = esp_rmaker_get_first_device();
    if (!device) {
        return ESP_OK;
    }
    bool is_service = false;
    if (strcmp(key, "services") == 0) {
        is_service = true;
    }
    json_gen_push_array(jptr, key);
    while (device) {
        if (device->is_service == is_service) {
            json_gen_start_object(jptr);
            json_gen_obj_set_string(jptr, "name", device->name);
            if (device->type) {
                json_gen_obj_set_string(jptr, "type", device->type);
            }
            if (device->attributes) {
                json_gen_push_array(jptr, "attributes");
                esp_rmaker_attr_t *attr = device->attributes;
                while (attr) {
                    esp_rmaker_report_attribute(attr, jptr);
                    attr = attr->next;
                }
                json_gen_pop_array(jptr);
            }
            if (device->primary) {
                json_gen_obj_set_string(jptr, "primary", device->primary->name);
            }
            if (device->params) {
                json_gen_push_array(jptr, "params");
                esp_rmaker_param_t *param = device->params;
                while (param) {
                    esp_rmaker_report_param_config(param, jptr);
                    param = param->next;
                }
                json_gen_pop_array(jptr);
            }
            json_gen_end_object(jptr);
        }
        device = device->next;
    }
    json_gen_pop_array(jptr);
    return ESP_OK;
}

esp_err_t esp_rmaker_report_node_config()
{
    char *publish_payload = calloc(1, MAX_NODE_CONFIG_SIZE);
    if (!publish_payload) {
        return ESP_FAIL;
    }
    json_gen_str_t jstr;
    json_gen_str_start(&jstr, publish_payload, MAX_NODE_CONFIG_SIZE, NULL, NULL);
    json_gen_start_object(&jstr);
    esp_rmaker_report_info(&jstr);
    esp_rmaker_report_node_attributes(&jstr);
    esp_rmaker_report_templates(&jstr);
    esp_rmaker_report_devices_or_services(&jstr, "devices");
    esp_rmaker_report_devices_or_services(&jstr, "services");
    if (json_gen_end_object(&jstr) < 0) {
        ESP_LOGE(TAG, "Buffer size %d not sufficient for Node Config.", MAX_NODE_CONFIG_SIZE);
        return ESP_FAIL;
    }
    json_gen_str_end(&jstr);
    char publish_topic[100];
    snprintf(publish_topic, sizeof(publish_topic), "node/%s/%s", esp_rmaker_get_node_id(), NODE_CONFIG_TOPIC_SUFFIX);
    ESP_LOGI(TAG, "Reporting Node Configuration");
    esp_err_t ret = esp_rmaker_mqtt_publish(publish_topic, publish_payload, strlen(publish_payload));
    free(publish_payload);
    return ret;
}
