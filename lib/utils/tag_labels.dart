import 'package:flutter/widgets.dart';
import 'package:medito/l10n/app_localizations.dart';

/// User-facing label for a server tag id. Unknown ids (a tag added on the
/// server before the app learned about it) fall back to the humanised id, so
/// new tags still render without an app update.
String tagLabel(BuildContext context, String tagId) {
  final l10n = AppLocalizations.of(context)!;
  return switch (tagId) {
    'sleep' => l10n.tagSleep,
    'stress' => l10n.tagStress,
    'anxiety' => l10n.tagAnxiety,
    'low_mood' => l10n.tagLowMood,
    'focus' => l10n.tagFocus,
    'calm' => l10n.tagCalm,
    'self_compassion' => l10n.tagSelfCompassion,
    'gratitude' => l10n.tagGratitude,
    'emotions' => l10n.tagEmotions,
    'pain' => l10n.tagPain,
    'confidence' => l10n.tagConfidence,
    'relationships' => l10n.tagRelationships,
    'grief' => l10n.tagGrief,
    'habit_building' => l10n.tagHabitBuilding,
    'breathing' => l10n.tagBreathing,
    'body_scan' => l10n.tagBodyScan,
    'loving_kindness' => l10n.tagLovingKindness,
    'open_awareness' => l10n.tagOpenAwareness,
    'visualization' => l10n.tagVisualization,
    'mantra' => l10n.tagMantra,
    'walking' => l10n.tagWalking,
    'reflection' => l10n.tagReflection,
    'sound' => l10n.tagSound,
    'guided_meditation' => l10n.tagGuidedMeditation,
    'talk' => l10n.tagTalk,
    'sleep_story' => l10n.tagSleepStory,
    'music' => l10n.tagMusic,
    'nature_sounds' => l10n.tagNatureSounds,
    'course_lesson' => l10n.tagCourseLesson,
    'beginners' => l10n.tagBeginners,
    'experienced' => l10n.tagExperienced,
    'teens_students' => l10n.tagTeensStudents,
    'teachers' => l10n.tagTeachers,
    'workplace' => l10n.tagWorkplace,
    'kids' => l10n.tagKids,
    'morning' => l10n.tagMorning,
    'evening' => l10n.tagEvening,
    'sos' => l10n.tagSos,
    'on_the_go' => l10n.tagOnTheGo,
    'crisis' => l10n.tagCrisis,
    'spanish' => l10n.tagSpanish,
    _ => _humanise(tagId),
  };
}

String _humanise(String id) {
  final words = id.replaceAll('_', ' ').trim();
  if (words.isEmpty) return id;
  return words[0].toUpperCase() + words.substring(1);
}
