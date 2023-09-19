import { StyleSheet, Text, TextInput, View, Pressable } from "react-native";
import { React, useState } from "react";
import theme from "../theme/theme";

const CardSetForm = ({ handleShowModal }) => {
  const [nameState, setNameState] = useState("");
  const [categoryState, setCategoryState] = useState("");
  const [descriptionState, setDescriptionState] = useState("");

  const handleNameChange = (text) => {
    setNameState(text);
  };
  const handleCategoryChange = (text) => {
    setCategoryState(text);
  };
  const handleDescriptionChange = (text) => {
    setDescriptionState(text);
  };

  const handleSubmitEvent = () => {
    console.log("need to implement submit action");
  };

  return (
    <Pressable style={styles.input_outer_form} onPress={handleShowModal}>
      <Pressable style={styles.input_inner_form}>
        <View style={styles.input_form_header}>
          <Text style={styles.form_header_text}>Create Card Set</Text>
        </View>
        <View style={styles.form_text_input}>
          <TextInput
            placeholder="Enter Card Set Name"
            value={nameState}
            style={styles.text_input}
            onChangeText={handleNameChange}
          />
        </View>
        <View style={styles.form_text_input}>
          <TextInput
            placeholder="Enter Card Set Category"
            value={categoryState}
            style={styles.text_input}
            onChangeText={handleCategoryChange}
          />
        </View>
        <View style={styles.form_detail_input}>
          <Text>Enter Card Set Description</Text>
          <TextInput
            style={styles.text_box}
            value={descriptionState}
            onChangeText={handleDescriptionChange}
          />
        </View>
        <Pressable style={styles.form_btn} onPress={handleSubmitEvent}>
          <Text style={styles.form_submit}>Add Set</Text>
        </Pressable>
      </Pressable>
    </Pressable>
  );
};

export default CardSetForm;

const styles = StyleSheet.create({
  input_outer_form: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "gray",
  },
  input_inner_form: {
    width: "70%",
    height: "70%",
    borderRadius: 2,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: theme.light_mode.bg_normal,
    elevation: 3, // This controls the shadow on Android
  },
  input_form_header: {
    flex: 4,
    backgroundColor: theme.light_mode.bg_dark,
    width: "100%",
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "center",
    elevation: 2,
    marginBottom: 10,
  },
  form_header_text: {
    color: theme.light_mode.bg_normal,
    fontSize: 20,
    fontWeight: "bold",
    fontStyle: "italic",
  },
  form_text_input: {
    flex: 1,
    width: "70%",
    alignItems: "center",
    justifyContent: "center",
  },
  text_input: {
    borderColor: "gray",
    borderBottomWidth: 1,
    width: "100%",
    paddingHorizontal: 4,
    fontSize: 14,
    fontWeight: "bold",
  },

  form_detail_input: {
    flex: 3,
    width: "70%",
    marginTop: 6,
  },
  text_box: {
    width: "100%",
    height: "80%",
    borderWidth: 1,
    borderColor: "gray",
    paddingHorizontal: 8,
    marginBottom: 16,
  },
  form_btn: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 2,
  },
  form_submit: {
    fontSize: 18,
    fontWeight: "bold",
    backgroundColor: theme.light_mode.bg_dark,
    color: theme.light_mode.bg_normal,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 30,
    fontStyle: "italic",
  },
});
