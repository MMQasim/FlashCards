import { StyleSheet, Text, View, Button } from "react-native";
import React from "react";
import { StatusBar } from "expo-status-bar";
import theme from "../theme/theme";
import Ionicons from "@expo/vector-icons/Ionicons";
import NavBar from "../Components/NavBar";
import FontAwesome from "@expo/vector-icons/FontAwesome";
import EvilIcons from "@expo/vector-icons/EvilIcons";
import { Entypo } from "@expo/vector-icons";
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
        <View style={styles.container}>
          <View>
            <Ionicons name="search" size={30} />
            <Ionicons name="add" size={30} />
            <Text>Flash Cards</Text>
          </View>
          <View>
            <Text>library section</Text>
          </View>
        </View>
        <NavBar></NavBar>
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
  container: {
    backgroundColor: "transparnt",
    paddingHorizontal: 20,
    paddingTop: 30,
    height: "90%",
  },
});
