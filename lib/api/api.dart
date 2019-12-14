import 'package:cloud_firestore/cloud_firestore.dart';

class Api {
  final Firestore _db = Firestore.instance;
  final String path;
  CollectionReference ref;

  Api(this.path) {
    ref = _db.collection(path);
  }

  Future<QuerySnapshot> getDataCollection() {
    return ref.getDocuments();
  }

  Stream<QuerySnapshot> streamDataCollection() {
    return ref.snapshots();
  }

  Future<DocumentSnapshot> getDocumentById(String id) {
    return ref.document(id).get();
  }

  Future<void> removeDocument(String id) {
    return ref.document(id).delete();
  }

  Future<DocumentReference> addDocument(Map data) {
    return ref.add(data);
  }

  //https://pub.dev/packages/cloud_firestore
  static Future<void> updateSubscribers(String email) {
    return Firestore.instance
        .collection('subscribers')
        .document()
        .setData({"1": email});
  }
}
