import { StyleSheet, Text, View } from "react-native";
import { StatusBar } from "expo-status-bar";
import React from "react";
import theme from "../theme/theme";
import SearchBar from "../Components/SearchBar";
import NavBar from "../Components/NavBar";
import Ionicons from "@expo/vector-icons/Ionicons";
import Heading from "../Components/Heading";

const Topic = ({ navigation }) => {
  React.useLayoutEffect(() => {
    navigation.setOptions({
      headerShown: false,
    });
  }, [navigation]);
  return (
    <>
      <StatusBar style={theme.light_mode.status_bar} translucent={false} />
      <View style={styles.core_container}>
        <View style={theme.main_container}>
          <Heading text={"Library"} />
          <SearchBar />
          <View>
            <Ionicons name="add" size={30} />
            <Text>Topics</Text>
          </View>
          <View>
            <Text>library section</Text>
          </View>
        </View>
        <NavBar navigation={navigation} active_index={1}></NavBar>
      </View>
    </>
  );
};

export default Topic;

const styles = StyleSheet.create({
  core_container: {
    flex: 1,
    backgroundColor: theme.light_mode.bg_light,
  },
});
