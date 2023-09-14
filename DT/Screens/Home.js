import { StyleSheet, Text, View, Button } from "react-native";
import React from "react";
import { StatusBar } from "expo-status-bar";
import theme from "../theme/theme";

const Home = ({ navigation }) => {
  React.useLayoutEffect(() => {
    navigation.setOptions({
      headerShown: false,
    });
  }, [navigation]);

  return (
    <>
      <StatusBar style={theme.light_mode.status_bar} translucent={false} />
      <View style={styles.core_container}>
        <View style={styles.hero}></View>
        <View style={styles.container}>
          <Text>Hello qasim!</Text>
          <Text>IdiotS ?</Text>
          <Button title="Hello Me" />
        </View>
      </View>
    </>
  );
};

export default Home;

const styles = StyleSheet.create({
  core_container: {
    flex: 1,
    backgroundColor: theme.light_mode.bg_light,
  },
  hero: {
    flex: 2,
    backgroundColor: "red",
  },
  container: {
    flex: 1,
    backgroundColor: "transparnt",
  },
});
