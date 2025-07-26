class ClassificationProbabilities {
  final Map<String, double> _probabilities;

  ClassificationProbabilities(this._probabilities);

  double getProbability(String className) {
    return _probabilities[className] ?? 0.0;
  }

  List<String> getClasses() {
    return _probabilities.keys.toList();
  }

  List<double> getProbabilities() {
    return _probabilities.values.toList();
  }

  String getMostProbableClass() {
    return _probabilities.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  @override
  String toString() {
    return _probabilities.toString();
  }
}
