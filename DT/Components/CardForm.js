import {
  StyleSheet,
  Text,
  View,
  TextInput,
  Pressable,
  PermissionsAndroid,
  Alert,
} from "react-native";
import React from "react";
import { useState } from "react";
import theme from "../theme/theme";
import { Ionicons, AntDesign, MaterialIcons } from "@expo/vector-icons";
import * as SQLite from "expo-sqlite";
import conf from "../conf";
import { launchCamera, launchImageLibrary } from "react-native-image-picker";

const CardForm = ({ onClose }) => {
  const DB = SQLite.openDatabase(conf.LocalDB);
  const [frontTextState, setFrontTextState] = useState("");
  const [backTextState, setBackTextState] = useState("");

  const handleFrontTextChange = (text) => {
    setFrontTextState(text);
  };
  const handleBackTextChange = (text) => {
    setBackTextState(text);
  };
  const checkPermitions = async () => {
    try {
      const allowed = await PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.CAMERA
        // PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
        // PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
      );
      console.log(allowed);

      if (
        allowed === PermissionsAndroid.RESULTS.GRANTED
        // && allowed[PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE] ===
        //   PermissionsAndroid.RESULTS.GRANTED &&
        // allowed[PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE] ===
        //   PermissionsAndroid.RESULTS.GRANTED
      ) {
        return true;
      } else {
        console.log("it is err");
        if (allowed !== PermissionsAndroid.RESULTS.GRANTED) {
          Alert.alert("CAMERA", "CAMERA ACCRESS DENIED", [
            { text: "OK", onPress: () => console.log("OK Pressed") },
          ]);
        }
        // if (
        //   allowed[PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE] !==
        //   PermissionsAndroid.RESULTS.GRANTED
        // ) {
        //   Alert.alert("READ", "READ ACCRESS DENIED", [
        //     { text: "OK", onPress: () => console.log("OK Pressed") },
        //   ]);
        // }
        // if (
        //   allowed[PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE] !==
        //   PermissionsAndroid.RESULTS.GRANTED
        // ) {
        //   Alert.alert("WRITE", "WRITE ACCRESS DENIED", [
        //     { text: "OK", onPress: () => console.log("OK Pressed") },
        //   ]);
        // }
        return false;
      }
    } catch (error) {
      console.log(error);
    }
  };

  const getPermitions = async () => {
    try {
      const allo = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.CAMERA
        // PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
        // PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
      );
      if (allo === PermissionsAndroid.RESULTS.GRANTED) {
        return true;
      }
      return false;
    } catch (err) {
      console.log("ok");
    }
  };

  const handleOpenCamera = async () => {
    const re = await getPermitions();
    try {
      const granted = await checkPermitions();
      console.log(granted);
      if (granted) {
        console.log(granted);
      } else {
        console.log(granted);
      }
    } catch (error) {
      console.error("Error fetching data:", error);
    }
  };
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
          <Text>Image view</Text>
          <Text>{frontTextState}</Text>
        </View>
        <View style={styles.input_container}>
          <TextInput
            placeholder="Add text "
            value={frontTextState}
            style={styles.textInput}
            onChangeText={handleFrontTextChange}
          />
          <Pressable>
            <MaterialIcons name="photo-library" size={24} color="black" />
          </Pressable>
          <Pressable onPress={handleOpenCamera}>
            <Ionicons name="md-camera-outline" size={30} color="black" />
          </Pressable>
        </View>
      </View>
      <Text style={styles.title_text}>Back Section</Text>
      <View style={styles.outer_input_container}>
        <View style={styles.display}>
          <Text>Image view</Text>
          <Text>{backTextState}</Text>
        </View>
        <View style={styles.input_container}>
          <TextInput
            placeholder="Add text "
            value={backTextState}
            onChangeText={() => handleBackTextChange()}
            style={styles.textInput}
          />
          <Pressable>
            <MaterialIcons name="photo-library" size={24} color="black" />
          </Pressable>

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
