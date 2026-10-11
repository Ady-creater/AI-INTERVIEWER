import 'package:flutter/material.dart';
import 'package:frontend/screens/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(home: Home()));
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            border: BoxBorder.fromLTRB(
              bottom: BorderSide(
                width: 0.5,
                color: Colors.black,
                style: BorderStyle.solid,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.account_circle_outlined),
            iconSize: 35,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Expanded(
          child: Container(
            margin: EdgeInsetsGeometry.fromLTRB(5, 12, 5, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: [
                Text(
                  "Welcome back, Aayush!",
                  style: TextStyle(fontSize: 32, fontFamily: "ArchivoBlack"),
                ),
                Text(
                  "Ready to ace your next interview?",
                  style: TextStyle(
                    fontSize: 23,
                    wordSpacing: 3,
                    fontFamily: "BricolageGrotesque",
                  ),
                ),

                Container(
                  height: 85,
                  margin: EdgeInsetsGeometry.only(top: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 0, 24, 178),
                        const Color.fromARGB(255, 160, 253, 89),
                      ],
                    ),
                    borderRadius: BorderRadiusGeometry.circular(15),
                    boxShadow: [BoxShadow(offset: Offset(0, 3), blurRadius: 7)],
                  ),
                  child: MaterialButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Flex(
                            direction: Axis.horizontal,
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 5,
                            children: [
                              Flex(
                                direction: Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.mic,
                                    size: 40,
                                    color: Colors.green,
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.videocam,
                                        size: 27,
                                        color: Colors.white,
                                      ),
                                      Icon(
                                        Icons.videocam,
                                        size: 27,
                                        color: Colors.green,
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              Text(
                                "Start a Mock Interview",
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsetsGeometry.only(top: 20),
                  child: Text(
                    "Practice audio-visual interviews with an AI professional.",
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                ),

                Padding(
                  padding: EdgeInsetsGeometry.only(top: 20),
                  child: Container(
                    height: 110,
                    width: 400,
                    margin: EdgeInsetsGeometry.only(top: 20),
                    padding: EdgeInsetsGeometry.fromLTRB(5, 10, 5, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color.fromARGB(255, 0, 24, 178),
                          const Color.fromARGB(255, 160, 253, 89),
                        ],
                      ),
                      borderRadius: BorderRadiusGeometry.circular(15),
                      boxShadow: [
                        BoxShadow(offset: Offset(0, 3), blurRadius: 7),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Flex(
                            direction: Axis.horizontal,
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 5,
                            children: [
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text(
                                    "Prepare with specific job roles",
                                    style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Row(
                                    spacing: 8,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 120,
                                        decoration: BoxDecoration(
                                          border: BoxBorder.all(
                                            width: 1,
                                            color: Colors.black,
                                          ),
                                          color: const Color.fromARGB(
                                            255,
                                            25,
                                            30,
                                            180,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),

                                        child: Text(
                                          "Software Engineer",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Container(
                                        width: 120,
                                        decoration: BoxDecoration(
                                          border: BoxBorder.all(
                                            width: 1,
                                            color: Colors.black,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          color: const Color.fromARGB(
                                            255,
                                            25,
                                            30,
                                            180,
                                          ),
                                        ),

                                        child: Text(
                                          "Data Scientist",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Container(
                                        width: 120,
                                        decoration: BoxDecoration(
                                          border: BoxBorder.all(
                                            width: 1,
                                            color: Colors.black,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          color: const Color.fromARGB(
                                            255,
                                            25,
                                            30,
                                            180,
                                          ),
                                        ),

                                        child: Text(
                                          "ML Engineer",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: ElevatedButton(
          onPressed: () {},
          style: ButtonStyle(
            backgroundColor: WidgetStateColor.fromMap(
              <WidgetStatesConstraint, Color>{
                WidgetState.focused: Colors.blue,
                WidgetState.any: Colors.green,
              },
            ),
            elevation: WidgetStatePropertyAll(10),
          ),
          child: Text(
            'START',
            style: TextStyle(color: Colors.white, fontSize: 25),
          ),
        ),
      ),
    )
    );
  }
}
