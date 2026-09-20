/// Single source of truth for the About screen's content.
///
/// Profile summaries are capped at 75 words each. Website, store, and contact
/// values below are used verbatim by the About screen's open-in-browser
/// buttons — keep them as plain hostnames/URLs.
class AboutConfig {
  /// Display name of the book/content author.
  static const String authorName = 'Dr Hikma Akinfunmilola Atanda';

  /// 73-word author profile shown under "About the Author".
  static const String authorBio =
      'Dr Hikma Akinfunmilola Atanda is a licensed physician (MBBS) with five '
      'years of patient-facing clinical work: a 12-month house-officer rotation, '
      'three years of supervised inpatient case management, and four years of '
      'frontline community health delivery across northern Nigeria. Trained where '
      'physician scarcity makes senior students working clinicians, she built '
      'judgement on live patients under consultant supervision. She also designs '
      'and ships medical education platforms, and is completing HL7 FHIR and '
      'Google Cybersecurity certifications.';

  /// Co-author slot — fill in when confirmed.
  static const String coAuthorName = 'To be announced';

  /// Shown under "Co-Author" until the co-author is confirmed.
  static const String coAuthorBio = 'Co-author details to be announced.';

  /// Person credited as the app developer.
  static const String appDeveloperName = 'Asor Ahura';

  /// 75-word developer profile shown under "App Developer".
  static const String appDeveloperBlurb =
      'Asor Ahura is an AI engineer and digital health technologist with 7+ '
      'years building AI-enabled systems for low-resource settings. He leads '
      'technology delivery across 60+ facilities in five Nigerian states, with '
      'work spanning Cameroon, Rwanda, and India. He writes Python, SQL, and '
      'TypeScript, applies LLMs, vision, OCR, and analytics with human-in-the-loop '
      'governance aligned to HIPAA, GDPR, and NHREC ethics, and has trained 370+ '
      'staff. MSc Information Management; Azure AI, Oracle Cloud, and ISC2 '
      'cybersecurity certified.';

  /// Public website. Opens in the device browser from the About screen.
  static const String websiteUrl = 'https://www.enchiridion.site';

  /// URL where readers can order a physical copy of the book.
  static const String physicalCopyUrl =
      'https://www.enchiridion.site/get-paperback';

  /// Short paragraph describing the app shown under "About the App".
  static const String aboutAppBlurb =
      'Enchiridion is an offline-first clinical companion: textbooks, '
      'calculators, instrumentation guides, OSCE stations, and exam prep '
      'with spaced repetition — on your device, online or offline.';

  /// Copyright line rendered at the bottom of the About screen and in the
  /// data-protection section.
  static const String copyrightNotice =
      '© 2026 Hikma Akinfunmilola Atanda. All rights reserved. '
      'Enchiridion content and software may not be reproduced without permission.';

  /// Contact address for support, copyright queries, and data-protection
  /// requests (access, correction, deletion).
  static const String contactEmail = 'support@enchiridion.site';

  /// Direct email for the author (content queries, errata, permissions).
  static const String authorEmail = 'hikma@enchiridion.site';

  /// Direct email for the app developer (bug reports, technical support).
  static const String developerEmail = 'asor@asorahura.com';
}
