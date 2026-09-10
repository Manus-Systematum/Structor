/// What the reference list costs against today's data — not what it prints.
///
/// The export bundled as `assets/reference_snapshot.json` prints **2,000** and
/// was a legal Strike Force when it was made. Two of its sixteen units cost
/// ten points more now, and Games Workshop's own published points back the
/// higher figure in both cases:
///
/// | unit | export | GW today |
/// | --- | --- | --- |
/// | Crisis Starscythe Battlesuits (×2) | 120 | 100 + 6 flamers at 5 = 130 |
/// | The Twin Lance | 220 | 230 |
///
/// Whether Games Workshop raised them or the exporting app had them wrong is
/// not something this repository can tell, and these tests do not claim
/// either. The engine's own `test/support.dart` carries the same constant and
/// the same reasoning; this copy exists because the two packages do not share
/// test code.
///
/// **A fresh export would restore the stronger check**, where the computed
/// total and the printed total are the same number.
const referenceListCost = 2030;
