import {
  StyleSheet,
  Text,
  View,
  TextInput,
  Pressable,
  Image,
} from "react-native";
import React from "react";
import { useState } from "react";
import theme from "../theme/theme";
import { Ionicons, AntDesign, MaterialIcons } from "@expo/vector-icons";
import * as SQLite from "expo-sqlite";
import conf from "../conf";
import Camera from "../Tools/Camera";

const CardForm = ({ onClose }) => {
  const DB = SQLite.openDatabase(conf.LocalDB);
  const [frontTextState, setFrontTextState] = useState("");
  const [frontTextErrorState, setFrontTextErrorState] = useState(false);
  const [frontImgState, setFrontImgState] = useState("");
  const [backTextState, setBackTextState] = useState("");
  const [backTextErrorState, setBackTextErrorState] = useState(false);
  const [backImgState, setBackImgState] = useState("");

  const handleFrontTextChange = (text) => {
    setFrontTextState(text);
    if (notContainSpecialCharacters(text)) {
      setFrontTextErrorState(false);
    } else {
      setFrontTextErrorState(true);
    }
  };
  const handleBackTextChange = (text) => {
    console.log(text);
    setBackTextState(text);
    if (notContainSpecialCharacters(text)) {
      setBackTextErrorState(false);
    } else {
      setBackTextErrorState(true);
    }
  };

  const handleOpenCamera = async (setState) => {
    const imgUri = await Camera(true);
    setState(imgUri);
  };

  const handleOpenGallery = async (setState) => {
    const imgUri = await Camera(false);
    setState(imgUri);
  };

  function notContainSpecialCharacters(inputString) {
    const pattern = /^[^!@#$%`&*_\+\^=~:?{};'"\.>,\/<()|\-]+$/;
    return pattern.test(inputString);
  }

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
          <Image
            source={
              frontImgState === ""
                ? require("../assets/placeholderimg.png")
                : { uri: frontImgState }
            }
            style={styles.img}
            resizeMode="contain"
          />
        </View>
        <View style={styles.input_container}>
          <TextInput
            placeholder="Add text "
            placeholderTextColor={theme.light_mode.bg_normal}
            value={frontTextState}
            style={
              frontTextErrorState ? styles.errorTextInput : styles.textInput
            }
            onChangeText={handleFrontTextChange}
          />
          <Pressable onPress={() => handleOpenGallery(setFrontImgState)}>
            <MaterialIcons name="photo-library" size={24} color="white" />
          </Pressable>
          <Pressable onPress={() => handleOpenCamera(setFrontImgState)}>
            <Ionicons name="md-camera-outline" size={30} color="white" />
          </Pressable>
        </View>
      </View>
      <Text style={styles.title_text}>Back Section</Text>
      <View style={styles.outer_input_container}>
        <View style={styles.display}>
          <Image
            source={
              backImgState === ""
                ? require("../assets/placeholderimg.png")
                : { uri: backImgState }
            }
            style={styles.img}
            resizeMode="contain"
          />
        </View>
        <View style={styles.input_container}>
          <TextInput
            placeholder="Add text "
            placeholderTextColor={theme.light_mode.bg_normal}
            value={backTextState}
            onChangeText={handleBackTextChange}
            style={
              backTextErrorState ? styles.errorTextInput : styles.textInput
            }
          />
          <Pressable onPress={() => handleOpenGallery(setBackImgState)}>
            <MaterialIcons name="photo-library" size={24} color="white" />
          </Pressable>
          <Pressable onPress={() => handleOpenCamera(setBackImgState)}>
            <Ionicons name="md-camera-outline" size={30} color="white" />
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
    backgroundColor: theme.light_mode.bg_normal,
    borderTopRightRadius: 15,
    borderTopLeftRadius: 15,
    alignItems: "center",
  },
  input_container: {
    height: "20%",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: theme.light_mode.bg_dark,
    borderBottomLeftRadius: 13,
    borderBottomRightRadius: 13,
  },
  textInput: {
    flex: 1 / 2,
    fontSize: 18,
    borderBottomWidth: 1,
    borderBottomColor: theme.light_mode.bg_normal,
    marginHorizontal: 5,
    color: theme.light_mode.bg_normal,
  },
  errorTextInput: {
    flex: 1 / 2,
    fontSize: 18,
    borderBottomWidth: 1,
    borderBottomColor: "pink",
    marginHorizontal: 5,
    color: "pink",
    fontWeight: "bold",
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

  img: {
    width: "100%",
    height: "100%",
    borderTopRightRadius: 13,
    borderTopLeftRadius: 13,
  },
});
