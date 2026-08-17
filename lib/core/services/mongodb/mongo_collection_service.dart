import 'package:mongo_dart/mongo_dart.dart';



import 'package:open_space_parking/core/services/api/http_mongo_collection_service.dart';

import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';



class MongoCollectionService {

  MongoCollectionService(

    this._databaseService, {

    HttpMongoCollectionService? httpService,

  }) : _httpService = httpService;



  final MongoDatabaseService _databaseService;

  final HttpMongoCollectionService? _httpService;



  Future<Map<String, dynamic>?> findOne({

    required String collectionName,

    required SelectorBuilder selector,

  }) {

    if (_httpService case final http?) {

      return http.findOne(

        collectionName: collectionName,

        selector: selector,

      );

    }

    return _databaseService.collection(collectionName).findOne(selector);

  }



  Future<List<Map<String, dynamic>>> findMany({

    required String collectionName,

    required SelectorBuilder selector,

  }) async {

    if (_httpService case final http?) {

      return http.findMany(

        collectionName: collectionName,

        selector: selector,

      );

    }

    return _databaseService.collection(collectionName).find(selector).toList();

  }



  Future<WriteResult> insertOne({

    required String collectionName,

    required Map<String, dynamic> document,

  }) {

    if (_httpService case final http?) {

      return http.insertOne(

        collectionName: collectionName,

        document: document,

      );

    }

    return _databaseService.collection(collectionName).insertOne(document);

  }



  Future<WriteResult> updateOne({

    required String collectionName,

    required SelectorBuilder selector,

    required ModifierBuilder modifier,

  }) {

    if (_httpService case final http?) {

      return http.updateOne(

        collectionName: collectionName,

        selector: selector,

        modifier: modifier,

      );

    }

    return _databaseService

        .collection(collectionName)

        .updateOne(selector, modifier);

  }



  Future<WriteResult> deleteOne({

    required String collectionName,

    required SelectorBuilder selector,

  }) {

    if (_httpService case final http?) {

      return http.deleteOne(

        collectionName: collectionName,

        selector: selector,

      );

    }

    return _databaseService.collection(collectionName).deleteOne(selector);

  }

}


