/// Attribution for the bundled sample photos (Wikimedia Commons). Photos are cropped and resized.
class PhotoCredit {
  const PhotoCredit(
      {required this.subject,
      required this.title,
      required this.author,
      required this.license,
      required this.url});
  final String subject, title, author, license, url;

  /// Link to the licence text where the photo is not public domain.
  String? get licenseUrl => license.startsWith('CC BY-SA 4.0')
      ? 'https://creativecommons.org/licenses/by-sa/4.0/'
      : null;
}

const photoCredits = <PhotoCredit>[
  PhotoCredit(
      subject: "Portland cement 50 kg",
      title: "Portland Cement Bags",
      author: "KVD",
      license: "Public domain",
      url: "https://commons.wikimedia.org/wiki/File:Portland_Cement_Bags.jpg"),
  PhotoCredit(
      subject: "Fresh cocoa beans",
      title: "Cocoa beans in Guadeloupe",
      author: "Pkraemer",
      license: "CC BY-SA 4.0",
      url:
          "https://commons.wikimedia.org/wiki/File:Cocoa_beans_in_Guadeloupe.jpg"),
  PhotoCredit(
      subject: "Iron rods 12 mm",
      title: "A bunch of rebar up close",
      author: "W.carter",
      license: "CC BY-SA 4.0",
      url:
          "https://commons.wikimedia.org/wiki/File:A_bunch_of_rebar_up_close.jpg"),
  PhotoCredit(
      subject: "Cassava flour 25 kg",
      title: "Cassava flour",
      author: "Hajia Hijjah",
      license: "CC BY-SA 4.0",
      url: "https://commons.wikimedia.org/wiki/File:Cassava_flour.jpg"),
  PhotoCredit(
      subject: "Sand (tipper load)",
      title: "Pile of Sand for Building in Anambra State",
      author: "Johnnybam",
      license: "CC BY-SA 4.0",
      url:
          "https://commons.wikimedia.org/wiki/File:Pile_of_Sand_for_Building_in_Anambra_State.jpg"),
  PhotoCredit(
      subject: "Generator 20 kVA (hire)",
      title: "Sudhir diesel generator",
      author: "Microrao",
      license: "CC BY-SA 4.0",
      url:
          "https://commons.wikimedia.org/wiki/File:Sudhir_diesel_generator.jpg"),
];
