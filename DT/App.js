import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import * as SQLite from "expo-sqlite";
import { useEffect, useState } from "react";
import Home from "./Screens/Home";
import Topic from "./Screens/Topic";
import Stats from "./Screens/Stats";
import { Modal, Text } from "react-native";
import conf from "./conf";
import FlashTest from "./Screens/FlashTest";

export default function App() {
  const Stack = createNativeStackNavigator();

  const createTable = (query) => {
    const DB = SQLite.openDatabase(conf.LocalDB);
    DB.transaction((tx) =>
      tx.executeSql(
        query,
        null,
        (txtObj, resObj) => {
          console.log("Table ready");
        },
        (txtObj, error) => {
          console.log(error);
        }
      )
    );
  };

  useEffect(() => {
    const cardSetQuery =
      "CREATE TABLE IF NOT EXISTS CardSet(uuid TEXT PRIMARY KEY,Name TEXT,Category TEXT,Detail TEXT )";
    const cardQuery =
      "CREATE TABLE IF NOT EXISTS Card(uuid TEXT PRIMARY KEY,FrontText TEXT,FrontImg TEXT,BackText TEXT,BackImg TEXT ,CardSetUuid Text,FOREIGN KEY (CardSetUuid) REFERENCES CardSet (uuid))";
    createTable(cardSetQuery);
    createTable(cardQuery);
  }, []);

  return (
    <>
      <NavigationContainer>
        <Stack.Navigator initialRouteName="Home">
          <Stack.Screen name="Home" component={Home} />
          <Stack.Screen name="Topic" component={Topic} />
          <Stack.Screen name="FlashTest" component={FlashTest} />
          <Stack.Screen name="Stats" component={Stats} />
        </Stack.Navigator>
      </NavigationContainer>
      {/* <StatusBar style={theme.light_mode.status_bar} translucent={false} />
      <View style={styles.core_container}>
        <View style={styles.hero}></View>
        <View style={styles.container}>
          <Text>Hello qasim!</Text>
          <Text>IdiotS ?</Text>
          <Button title="Hello Me" />
        </View>
  </View>*/}
    </>
  );
}
