import { StyleSheet, Text, View, TextInput, Pressable } from "react-native";
import React from "react";
import { useState } from "react";
import theme from "../theme/theme";
import { Ionicons, AntDesign } from "@expo/vector-icons";
const CardForm = ({ onClose }) => {
  return (
    <View style={styles.outer_container}>
      <Pressable onPress={onClose}>
        <AntDesign
          name="close"
          size={30}
          color="black"
          style={{ alignSelf: "flex-end" }}
        />
      </Pressable>

      <Text style={styles.title_text}>Front Section</Text>

      <View style={styles.outer_input_container}>
        <View style={styles.display}>
          <Text>Text view</Text>
          <Text>Image view</Text>
        </View>
        <View style={styles.input_container}>
          <TextInput placeholder="Add text " style={styles.textInput} />
          <Pressable>
            <Ionicons name="md-camera-outline" size={30} color="black" />
          </Pressable>
        </View>
      </View>
      <Text style={styles.title_text}>Back Section</Text>
      <View style={styles.outer_input_container}>
        <View style={styles.display}>
          <Text>Text view</Text>
          <Text>Image view</Text>
        </View>
        <View style={styles.input_container}>
          <TextInput placeholder="Add text " style={styles.textInput} />
          <Pressable>
            <Ionicons name="md-camera-outline" size={30} color="black" />
          </Pressable>
        </View>
      </View>
      <Pressable style={styles.submitBtn}>
        <Text style={styles.submitText}>SUBMIT</Text>
      </Pressable>
    </View>
  );
};

export default CardForm;

const styles = StyleSheet.create({
  outer_container: {
    width: "100%",
    height: "100%",
    backgroundColor: theme.light_mode.bg_light,
    paddingHorizontal: 20,
    paddingVertical: 20,
  },

  title_text: {
    fontSize: 24,
    fontWeight: "bold",
    textDecorationLine: "underline",
    textAlign: "center",
    marginHorizontal: 10,
    marginTop: 10,
    marginBottom: 2,
  },

  outer_input_container: {
    borderWidth: 2,
    flex: 1,
    margin: 5,
    borderRadius: 15,
  },
  display: {
    height: "80%",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: theme.light_mode.bg_normal,
    borderTopRightRadius: 15,
    borderTopLeftRadius: 15,
  },
  input_container: {
    height: "20%",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
  },
  textInput: {
    flex: 1 / 2,
    fontSize: 18,
    borderBottomWidth: 1,
    marginHorizontal: 5,
  },
  submitBtn: {
    marginTop: 5,
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 15,
    alignSelf: "center",
    backgroundColor: theme.light_mode.bg_dark,
  },
  submitText: {
    color: theme.light_mode.bg_normal,
    fontSize: 16,
  },
});
