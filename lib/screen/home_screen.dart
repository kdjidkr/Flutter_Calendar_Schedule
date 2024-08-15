import 'package:flutter/material.dart';
import 'package:calendar_scheduler/component/main_calendar.dart';
import 'package:calendar_scheduler/component/schedule_bottom_sheet.dart';
import 'package:calendar_scheduler/component/schedule_card.dart';
import 'package:calendar_scheduler/component/today_banner.dart';
import 'package:calendar_scheduler/const/colors.dart';
import 'package:calendar_scheduler/database/drift_database.dart';
import 'package:calendar_scheduler/provider/schedule_provider.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calendar_scheduler/model/schedule_model.dart';


// read() : 버튼을 누르는 것과 같이 일회성으로 데이터를 얻어와야 할때 쓰임
// watch() : 내부의 값이 바뀜을 감지하고 리빌드 해야할때 쓰임

// read()는 provider 안에 선언한 멤버변수의 상태를 변화시키기 위해서 쓰이고
// watch()는 read()를 통해 변한 멤버변수의 상태를 계속 보고 있기 위해 쓰인다.

// provider 안에 관리하고 싶은 상태를 read할지 watch할지 정의한다.

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>{
  DateTime selectedDate = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day);

  @override
  Widget build(BuildContext context) {
    // provider 변경이 있을 때마다 build() 함수 재실행
    // final provider = context.watch<ScheduleProvider>();
    // // 선택된 날짜 가져오기
    // final selectedDate = provider.selectedDate;
    // // 선택된 날짜에 해당하는 일정들 가져오기
    // final schedules = provider.cache[selectedDate] ?? [];

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: PRIMARY_COLOR,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isDismissible: true,
            builder: (_) => ScheduleBottomSheet(
              selectedDate: selectedDate,
            ),
            isScrollControlled: true,
          );
        },
        child: Icon(
          Icons.add,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            MainCalendar(
              onDaySelected: (selectedDate, focusedDate) => {
                onDaySelected(selectedDate, focusedDate, context),
              }, // 달력의 날짜가 탭될 때마다 실행됨
              selectedDate: selectedDate,
            ),
            SizedBox(height: 8.0),
            //
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('schedule',).where('date',isEqualTo: '${selectedDate.year}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}').snapshots(), builder: (context, snapshot)
            {return TodayBanner(selectedDate: selectedDate, count: snapshot.data?.docs.length ?? 0,);}),
            SizedBox(height: 8.0),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('schedule',).where('date',isEqualTo: '${selectedDate.year}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}').snapshots(), builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('일정 정보를 가져오지 못했습니다.'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container();
                }

                final schedules = snapshot.data!.docs.map((
                    QueryDocumentSnapshot e) =>
                    ScheduleModel.fromJson(
                        json: (e.data() as Map<String, dynamic>)),).toList();

                return ListView.builder(
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];

                    return Dismissible(
                      key: ObjectKey(schedule.id),
                      direction: DismissDirection.startToEnd,
                      onDismissed: (DismissDirection direction) {
                        FirebaseFirestore.instance.collection('schedule').doc(schedule.id).delete();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(
                            bottom: 8.0, left: 8.0, right: 8.0),
                        child: ScheduleCard(
                          startTime: schedule.startTime,
                          endTime: schedule.endTime,
                          content: schedule.content,
                        ),
                      ),
                    );
                  },
                );
              },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onDaySelected(DateTime selectedDate, DateTime focusedDate, BuildContext context) {
    setState(() {
      this.selectedDate = selectedDate;
    });
  }
}


// drift 플러그인을 이용해 내부 데이터베이스를 쓰고 싶을때
/*
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime selectedDate = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: PRIMARY_COLOR,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isDismissible: true,
            builder: (_) => ScheduleBottomSheet(
              selectedDate: selectedDate,
            ),
            isScrollControlled: true,
          );
        },
        child: Icon(
          Icons.add,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            MainCalendar(
              onDaySelected: onDaySelected, // 달력의 날짜가 탭될 때마다 실행됨
              selectedDate: selectedDate,
            ),
            SizedBox(height: 8.0),
            StreamBuilder(
                stream: GetIt.I<LocalDatabase>().watchSchedules(selectedDate),
                builder: (context, snapshot) {
                  return TodayBanner(
                    selectedDate: selectedDate,
                    count: snapshot.data?.length ?? 0,
                  );
                }),
            SizedBox(height: 8.0),
            Expanded(
              child: StreamBuilder<List<Schedule>>(
                  stream: GetIt.I<LocalDatabase>().watchSchedules(selectedDate),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Container();
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final schedule = snapshot.data![index];

                        return Dismissible(
                          key: ObjectKey(schedule.id),
                          direction: DismissDirection.startToEnd,
                          onDismissed: (DismissDirection direction) {
                            GetIt.I<LocalDatabase>()
                                .removeSchedule(schedule.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(
                                bottom: 8.0, left: 8.0, right: 8.0),
                            child: ScheduleCard(
                              startTime: schedule.startTime,
                              endTime: schedule.endTime,
                              content: schedule.content,
                            ),
                          ),
                        );
                      },
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }

  void onDaySelected(DateTime selectedDate, DateTime focusedDate) {
    setState(() {
      this.selectedDate = selectedDate;
    });
  }
}
*/