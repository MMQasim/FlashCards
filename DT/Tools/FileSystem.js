import { View, Text } from "react-native";
import React from "react";
import * as FS from "expo-file-system";
import { v4 as uuidv4 } from "uuid";

const imgDir = FS.documentDirectory + "images/";
const ensureDirExists = async () => {
  const dirInfo = await FS.getInfoAsync(imgDir);
  if (!dirInfo.exists) {
    console.log("Image directory doesn't exist, creating…");
    await FS.makeDirectoryAsync(imgDir, { intermediates: true });
  }
};

const saveFile = async (uri) => {
  await ensureDirExists();

  const uuid = uuidv4();
  const fileType = uri.split(".")[uri.split(".").length - 1];
  const tempFN = typeId + "-" + uuid + "." + fileType;
  const desDir = imgDir + tempFN;

  console.log(tempFN);
};

export { ensureDirExists, imgDir };
