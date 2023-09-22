import { StyleSheet, Text, View } from "react-native";
import React from "react";
import theme from "../theme/theme";
const EmptyNote = ({ text }) => {
  return (
    <View style={styles.container}>
      <Text style={styles.text}>{text}</Text>
    </View>
  );
};

export default EmptyNote;

const styles = StyleSheet.create({
  container: {
    backgroundColor: theme.light_mode.bg_normal,
    margin: 5,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderWidth: 2,
    borderRadius: 15,
    justifyContent: "center",
    alignItems: "center",
    height: 150,
  },
  text: {
    fontSize: 16,
    fontWeight: "bold",
  },
});
