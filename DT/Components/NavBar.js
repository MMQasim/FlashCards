import { Pressable, StyleSheet, View } from "react-native";
import React from "react";
import theme from "../theme/theme";
import { Ionicons, EvilIcons } from "@expo/vector-icons";
import { useState } from "react";

const NavBar = (props) => {
  const [iconHeight, setIconHeight] = useState();
  onLayout = (event) => {
    const { height } = event.nativeEvent.layout;
    setIconHeight(height / 2);
  };

  return (
    <View style={styles.nav_container} onLayout={this.onLayout}>
      <Pressable
        style={styles.nav_items}
        onPress={() => props.navigation.navigate("Topic")}
      >
        <Ionicons
          name="book"
          size={iconHeight}
          style={
            props.active_index == 1
              ? { ...styles.icon, color: theme.light_mode.bg_light }
              : styles.icon
          }
        />
      </Pressable>
      <Pressable
        style={styles.nav_items}
        onPress={() => props.navigation.navigate("Stats")}
      >
        <Ionicons
          name="stats-chart"
          size={iconHeight}
          style={
            props.active_index == 2
              ? { ...styles.icon, color: theme.light_mode.bg_light }
              : styles.icon
          }
        />
      </Pressable>
      <Pressable
        style={styles.nav_items}
        onPress={() => props.navigation.navigate("Home")}
      >
        <Ionicons
          name="home"
          size={iconHeight}
          style={
            props.active_index == 3
              ? { ...styles.icon, color: theme.light_mode.bg_light }
              : styles.icon
          }
        />
      </Pressable>
    </View>
  );
};

export default NavBar;

const styles = StyleSheet.create({
  nav_container: {
    height: "10%",
    flexDirection: "row",
    backgroundColor: theme.light_mode.bg_dark,
    alignItems: "center",
    paddingHorizontal: 20,
    alignItems: "center",
  },
  nav_items: {
    flex: 1,
    alignItems: "center",
  },
  icon: {
    color: "white",
    shadowColor: "white",
  },
});
