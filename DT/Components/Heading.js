import { StyleSheet, Text, View } from "react-native";
import React from "react";

const Heading = ({ text }) => {
  return (
    <View>
      <Text style={styles.logo_text}>{text}</Text>
    </View>
  );
};

export default Heading;

const styles = StyleSheet.create({
  logo_text: {
    textAlign: "center",
    fontSize: 24,
    fontWeight: "bold",
    textDecorationLine: "underline",
    fontStyle: "italic",
    textShadowColor: "gray",
    textShadowOffset: { width: 2, height: 2 },
    textShadowRadius: 5,
  },
});
