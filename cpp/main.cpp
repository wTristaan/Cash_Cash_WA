#include <filesystem>
#include "onnx_model_base.h"
#include "autobackend.h"
#include <opencv2/opencv.hpp>
#include <vector>
#include "utils/augment.h"
#include "constants.h"
#include "utils/common.h"
#include <iostream>
#include "json.hpp"
#include <chrono>
#include <thread>
#include <memory>
#include <random>


#define HEXFF 255

namespace fs = std::filesystem;
using json = nlohmann::json;

int _clamp(int lower, int higher, int val)
{
    if (val < lower)
        return 0;
    else if (val > higher)
        return 255;
    else
        return val;
}

json resultsToJson(const std::vector<YoloResults>& objs) {
    json jResults = json::array();
    for (const auto& result : objs) {
        json jResult;
        jResult["class_idx"] = result.class_idx;
        jResult["conf"] = result.conf;
        jResult["bbox"] = {result.bbox.x, result.bbox.y, result.bbox.width, result.bbox.height};
        jResults.push_back(jResult);
    }
    return jResults;
}

class YoloModelManager {
private:
    std::unique_ptr<AutoBackendOnnx> model;
    YoloModelManager() {}

public:
    YoloModelManager(YoloModelManager const&) = delete;
    void operator=(YoloModelManager const&) = delete;

    static YoloModelManager& getInstance() {
        static YoloModelManager instance;
        return instance;
    }

    void initializeModel(const std::string& modelPath, const std::string& onnx_logid, const std::string& onnx_provider) {
        if (!model) {
            model = std::make_unique<AutoBackendOnnx>(modelPath.c_str(), onnx_logid.c_str(), onnx_provider.c_str());
        }
    }

    AutoBackendOnnx* getModel() {
        return model.get();
    }
};

extern "C" {
__attribute__((visibility("default"))) __attribute__((used))
    void initializeYoloModel(const char* path) {
        const std::string modelPath = std::string(path);
        const std::string& onnx_provider = OnnxProviders::CPU;
        const std::string onnx_logid = "yolov8_inference2";
        YoloModelManager::getInstance().initializeModel(modelPath, onnx_logid, onnx_provider);
    }
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
char* iosDetection(unsigned char *p, size_t dataSize)
{
    float mask_threshold = 0.5f;
    float conf_threshold = 0.30f;
    float iou_threshold = 0.45f;
    int conversion_code = cv::COLOR_RGB2BGR;
    std::vector<unsigned char> dataVec(p, p + dataSize);
    cv::Mat imageF = cv::imdecode(dataVec, cv::IMREAD_UNCHANGED);
    AutoBackendOnnx* model = YoloModelManager::getInstance().getModel();
    std::vector<YoloResults> objs = model->predict_once(imageF, conf_threshold, iou_threshold, mask_threshold, conversion_code);
    json j = resultsToJson(objs);
    std::string jsonString = j.dump();
    return strdup(jsonString.c_str());
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
char* androidDetection(unsigned char *p, unsigned char *p1, unsigned char *p2, int bytesPerRow, int bytesPerPixel, int32_t width, int32_t height)
{
    float mask_threshold = 0.5f;
    float conf_threshold = 0.30f;
    float iou_threshold = 0.45f;
    int x, y, uvIndex, index;
    int yp, up, vp;
    int r, g, b;
    int rt, gt, bt;
    int conversion_code = cv::COLOR_BGR2RGB;
    AutoBackendOnnx* model = YoloModelManager::getInstance().getModel();
    uint32_t *src = (uint32_t*)malloc(sizeof(uint32_t) * (width * height));
    uint32_t *flipSrc = (uint32_t*)malloc(sizeof(uint32_t) * (width * height));
    cv::Mat image_bgr;
    cv::Mat finalImg;

    for (x = 0; x < width; ++x)
    {
        for (y = 0; y < height; ++y)
        {
            uvIndex = bytesPerPixel * ((int)floor(x / 2)) + bytesPerRow * ((int)floor(y / 2));
            index = y * width + x;
            yp = p[index];
            up = p1[uvIndex];
            vp = p2[uvIndex];
            rt = round(yp + vp * 1436 / 1024 - 179);
            gt = round(yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91);
            bt = round(yp + up * 1814 / 1024 - 227);
            r = _clamp(0, 255, rt);
            g = _clamp(0, 255, gt);
            b = _clamp(0, 255, bt);
            src[x + y * width] = (HEXFF << 24) | (b << 16) | (g << 8) | r;
        }
    }

    cv::Mat image(height, width, CV_8UC4, (void*)src);
    cv::cvtColor(image, image_bgr, cv::COLOR_BGRA2RGB);
    cv::rotate(image_bgr, finalImg, cv::ROTATE_90_CLOCKWISE);

    std::vector<YoloResults> objs = model->predict_once(finalImg, conf_threshold, iou_threshold, mask_threshold, conversion_code);
    json j = resultsToJson(objs);
    std::string jsonString = j.dump();
    return strdup(jsonString.c_str());

}
