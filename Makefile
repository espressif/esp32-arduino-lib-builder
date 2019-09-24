PROJECT_NAME := esp32-arduino-lib-builder

EXTRA_COMPONENT_DIRS += $(PROJECT_PATH)/components/esp-face/lib
EXTRA_COMPONENT_DIRS += $(PROJECT_PATH)/components/esp-face/image_util
EXTRA_COMPONENT_DIRS += $(PROJECT_PATH)/components/esp-face/face_detection
EXTRA_COMPONENT_DIRS += $(PROJECT_PATH)/components/esp-face/face_recognition

include $(IDF_PATH)/make/project.mk

IDF_INCLUDES = $(filter $(IDF_PATH)/components/%, $(COMPONENT_INCLUDES))
IDF_OUT = $(patsubst $(IDF_PATH)/components/%,%,$(IDF_INCLUDES))

PROJ_INCLUDES = $(filter-out $(PROJECT_PATH)/components/arduino/%,$(filter $(PROJECT_PATH)/components/%, $(COMPONENT_INCLUDES)))
PROJ_OUT = $(patsubst $(PROJECT_PATH)/components/%,%,$(PROJ_INCLUDES))

idf-libs: all
	@$(PROJECT_PATH)/tools/prepare-libs.sh $(IDF_OUT) $(PROJ_OUT)
