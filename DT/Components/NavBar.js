import { StyleSheet, Text, View } from "react-native";
import React from "react";
import theme from "../theme/theme";
import { Ionicons, EvilIcons } from "@expo/vector-icons";
import { useState } from "react";

const NavBar = () => {
  const [iconHeight, setIconHeight] = useState();
  onLayout = (event) => {
    const { height } = event.nativeEvent.layout;
    setIconHeight(height / 2);
  };

  return (
    <View style={styles.nav_container} onLayout={this.onLayout}>
      <View style={styles.nav_items}>
        <Ionicons name="book" size={iconHeight} style={styles.icon} />
      </View>
      <View style={styles.nav_items}>
        <Ionicons name="stats-chart" size={iconHeight} style={styles.icon} />
      </View>
      <View style={styles.nav_items}>
        <EvilIcons name="user" size={iconHeight} style={styles.icon} />
      </View>
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
  },
});
