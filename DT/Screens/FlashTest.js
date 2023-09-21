import { StyleSheet, Text, View } from "react-native";
import theme from "../theme/theme";
import { StatusBar } from "expo-status-bar";
import SearchBar from "../Components/SearchBar";
import NavBar from "../Components/NavBar";
import Heading from "../Components/Heading";
import React from "react";

const FlashTest = ({ navigation }) => {
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
            <Text>Test your self</Text>
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

export default FlashTest;

const styles = StyleSheet.create({
  core_container: {
    flex: 1,
    backgroundColor: theme.light_mode.bg_light,
  },
});
