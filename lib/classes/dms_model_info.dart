import 'dart:convert';

DmsModelInfo dmsModelInfroFromJson(String str) => DmsModelInfo.fromJson(json.decode(str));

String dmsModelInfroToJson(DmsModelInfo data) => json.encode(data.toJson());

class DmsModelInfo {
    int version;
    String modelLink;
    String modelName;
    List<String> labels;
    String labelsLink;

    DmsModelInfo({
        required this.version,
        required this.modelLink,
        required this.modelName,
        required this.labels,
        required this.labelsLink,
    });

    factory DmsModelInfo.fromJson(Map<String, dynamic> json) => DmsModelInfo(
        version: json["version"],
        modelLink: json["model link"],
        modelName: json["model name"],
        labels: List<String>.from(json["labels"].map((x) => x)),
        labelsLink: json["labels link"],
    );

    Map<String, dynamic> toJson() => {
        "version": version,
        "model link": modelLink,
        "model name": modelName,
        "labels": List<dynamic>.from(labels.map((x) => x)),
        "labels link": labelsLink,
    };
}