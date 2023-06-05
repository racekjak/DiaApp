double getLevelProgress(int level, int points) {
  int previousLevel = level - 1;
  int pointsNeeded = ((level + ((level / 5) * level)) * 75).floor();
  int pointsFromPreviousLevel =
      ((previousLevel + ((previousLevel / 5) * previousLevel)) * 75).floor();
  double progress = (points - pointsFromPreviousLevel) /
      (pointsNeeded - pointsFromPreviousLevel);

  if (progress < 0) {
    progress = 0;
  }

  return progress;
}
