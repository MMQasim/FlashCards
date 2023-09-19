import { BackHandler, Text, StyleSheet, View, Pressable } from "react-native";
import React from "react";
import Ionicons from "@expo/vector-icons/Ionicons";

const AddBtn = ({ action }) => {
  return (
    <View>
      <Pressable style={styles.icon} onPress={() => action()}>
        <Ionicons name="add" size={30} color={"white"} />
      </Pressable>
    </View>
  );
};

export default AddBtn;

const styles = StyleSheet.create({
  icon: {
    height: 40,
    borderWidth: 2,
    borderColor: "black",
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    alignSelf: "center",
    marginHorizontal: 8,
    marginBottom: 8,
    marginRight: 16,
    backgroundColor: "black",
    borderRadius: 100,
    width: 40,
  },
});
