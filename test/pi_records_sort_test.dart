import 'package:flutter_test/flutter_test.dart';

import 'package:Wallcraft/screens/tracking/pi_records_page.dart';

void main() {
  test('parseFlexibleDate parses 4-digit, 2-digit, MM/dd/yyyy, and BE years', () {
    expect(PiRecordsPage.parseFlexibleDate('25/12/2025'), DateTime(2025, 12, 25));
    expect(PiRecordsPage.parseFlexibleDate('30/10/26'), DateTime(2026, 10, 30));
    expect(PiRecordsPage.parseFlexibleDate('12/6/26'), DateTime(2026, 6, 12));
    expect(PiRecordsPage.parseFlexibleDate('11/15/2026'), DateTime(2026, 11, 15));
    expect(PiRecordsPage.parseFlexibleDate('05/03/2569'), DateTime(2026, 3, 5));
    expect(PiRecordsPage.parseFlexibleDate('-'), isNull);
    expect(PiRecordsPage.parseFlexibleDate(''), isNull);
  });

  test('sortRecords handles workflow order with blanks last and tie-breaks cleanly', () {
    final records = <Map<String, dynamic>>[
      {
        'orderNo': 'ORD-3',
        'etd': 'ของถึงลูกค้าแล้ว',
        'recordDate': '01/10/2026',
        'lastUpdate': '30/10/26',
        'deliveredDate': '-',
        'saleName': 'อ้อม',
      },
      {
        'orderNo': 'ORD-1',
        'etd': 'รอสั่ง',
        'recordDate': '05/10/2026',
        'lastUpdate': '-',
        'deliveredDate': '14/01/2027',
        'saleName': 'กิ๊ก',
      },
      {
        'orderNo': 'ORD-4',
        'etd': '-',
        'recordDate': '10/10/2026',
        'lastUpdate': '01/11/26',
        'deliveredDate': '11/04/2026',
        'saleName': 'บีม',
      },
      {
        'orderNo': 'ORD-2',
        'etd': 'รอโรงงานส่งมา Warehouse',
        'recordDate': '03/10/2026',
        'lastUpdate': '15/10/26',
        'deliveredDate': '-',
        'saleName': 'จูน',
      },
    ];

    final pendingFirst = records.map((e) => Map<String, dynamic>.from(e)).toList();
    PiRecordsPage.sortRecords(pendingFirst, PiRecordSortOption.statusPendingFirst);
    expect(
      pendingFirst.map((e) => e['orderNo']),
      ['ORD-1', 'ORD-2', 'ORD-3', 'ORD-4'],
    );

    final doneFirst = records.map((e) => Map<String, dynamic>.from(e)).toList();
    PiRecordsPage.sortRecords(doneFirst, PiRecordSortOption.statusDoneFirst);
    expect(
      doneFirst.map((e) => e['orderNo']),
      ['ORD-3', 'ORD-2', 'ORD-1', 'ORD-4'],
    );

    final byLastUpdate = records.map((e) => Map<String, dynamic>.from(e)).toList();
    PiRecordsPage.sortRecords(byLastUpdate, PiRecordSortOption.lastUpdateDesc);
    expect(
      byLastUpdate.map((e) => e['orderNo']),
      ['ORD-4', 'ORD-3', 'ORD-2', 'ORD-1'],
    );

    final byDeliveredSoonest = records.map((e) => Map<String, dynamic>.from(e)).toList();
    PiRecordsPage.sortRecords(byDeliveredSoonest, PiRecordSortOption.deliveredDateAsc);
    expect(
      byDeliveredSoonest.map((e) => e['orderNo']),
      ['ORD-4', 'ORD-1', 'ORD-2', 'ORD-3'],
    );

    final byOrderNo = records.map((e) => Map<String, dynamic>.from(e)).toList();
    PiRecordsPage.sortRecords(byOrderNo, PiRecordSortOption.orderNoAsc);
    expect(
      byOrderNo.map((e) => e['orderNo']),
      ['ORD-1', 'ORD-2', 'ORD-3', 'ORD-4'],
    );
  });
}
