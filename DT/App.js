import { StatusBar } from "expo-status-bar";
import { StyleSheet, Text, View, Button } from "react-native";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";

import Home from "./Screens/Home";
import Topic from "./Screens/Topic";

export default function App() {
  const Stack = createNativeStackNavigator();
  return (
    <>
      <NavigationContainer>
        <Stack.Navigator initialRouteName="Home">
          <Stack.Screen name="Home" component={Home} />
          <Stack.Screen name="Topic" component={Topic} />
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
