import { StyleSheet, View, TextInput, Pressable } from "react-native";
import Ionicons from "@expo/vector-icons/Ionicons";
import React from "react";
import theme from "../theme/theme";
import { useState } from "react";

const SearchBar = ({ search }) => {
  const [search_input, setSearchInput] = useState("");

  const onChangeTextHandler = (text) => {
    setSearchInput(text);
    search(search_input);
  };

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.input}
        value={search_input}
        onChangeText={onChangeTextHandler}
      ></TextInput>
      <Pressable style={styles.icon} onPress={() => search(search_input)}>
        <Ionicons name="search" size={30} color={theme.light_mode.bg_normal} />
      </Pressable>
    </View>
  );
};

export default SearchBar;

const styles = StyleSheet.create({
  container: {
    padding: 16,
    flexDirection: "row",
    alignItems: "center",
  },
  input: {
    height: 40,
    borderWidth: 1,
    fontSize: 16,
    textAlignVertical: "center",
    flex: 1,
    borderColor: theme.light_mode.bg_dark,
    backgroundColor: theme.light_mode.bg_dark,
    color: theme.light_mode.bg_normal,
    borderTopLeftRadius: 100,
    borderBottomLeftRadius: 100,
    paddingHorizontal: 8,
    borderRightWidth: 0,
    paddingLeft: 16,
  },
  icon: {
    borderColor: theme.light_mode.bg_dark,
    backgroundColor: theme.light_mode.bg_dark,
    height: 40,
    paddingHorizontal: 8,
    paddingRight: 16,
    borderWidth: 1,
    borderLeftWidth: 0,
    borderTopRightRadius: 100,
    borderBottomRightRadius: 100,
    justifyContent: "center",
  },
});
