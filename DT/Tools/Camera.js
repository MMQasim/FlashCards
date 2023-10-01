import * as ImagePicker from "expo-image-picker";
import { Alert } from "react-native";
const Camera = async (cam) => {
  // No permissions request is necessary for launching the image library
  const options = {
    mediaTypes: ImagePicker.MediaTypeOptions.Images,
    allowsEditing: true,
    aspect: [8, 6],
    quality: 1,
    allowsMultipleSelection: false,
  };
  let result;
  if (!cam) {
    result = await ImagePicker.launchImageLibraryAsync(options);
    console.log(result);
    if (!result.canceled) {
      return result.assets[0].uri;
    }
    return "";
  } else {
    let permission = await ImagePicker.requestCameraPermissionsAsync();
    console.log(permission);
    if (permission.status !== "denied") {
      result = await ImagePicker.launchCameraAsync(options);
      console.log(result);
      if (!result.canceled) {
        return result.assets[0].uri;
      }
      return "";
    }
    Alert.alert("ALLOW ACCESS", "CAMERA ACCRESS DENIED", [
      { text: "Close", onPress: () => console.log("Colsed") },
    ]);
    return "";
  }
};

export default Camera;
