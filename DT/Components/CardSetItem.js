import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import React from "react";
import theme from "../theme/theme";
import { MaterialIcons } from "@expo/vector-icons";

const CardSetItem = ({
  uuid,
  name,
  category,
  detail,
  onDeleteAction,
  onClickAction,
}) => {
  return (
    <Pressable style={styles.outer}>
      <View style={styles.title_box}>
        <Text style={styles.title}>{name}</Text>
        <Text style={styles.type}>{category}</Text>
      </View>
      <ScrollView style={styles.info}>
        <Text style={styles.info_text}>{detail}</Text>
      </ScrollView>
      <Pressable style={styles.action} onPress={onDeleteAction}>
        <MaterialIcons
          name="delete-outline"
          size={30}
          color={theme.light_mode.bg_normal}
        />
      </Pressable>
    </Pressable>
  );
};

export default CardSetItem;

const styles = StyleSheet.create({
  outer: {
    elevation: 5,
    flexDirection: "row",
    borderWidth: 2,
    borderRadius: 10,
    margin: 8,
  },
  title_box: {
    backgroundColor: theme.light_mode.bg_dark,
    minWidth: 60,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  title: {
    fontSize: 22,
    color: theme.light_mode.bg_normal,
    fontWeight: "bold",
    marginBottom: 5,
  },
  type: {
    fontSize: 14,
    color: theme.light_mode.bg_normal,
    fontStyle: "italic",
  },
  info: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    backgroundColor: theme.light_mode.bg_normal,
  },
  info_text: {
    fontSize: 16,
    color: theme.light_mode.bg_dark,
  },
  action: {
    backgroundColor: theme.light_mode.bg_dark,
    paddingHorizontal: 10,
    paddingVertical: 5,
    alignItems: "center",
    justifyContent: "center",
  },
});
