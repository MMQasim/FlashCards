import {
  StyleSheet,
  Text,
  View,
  Modal,
  TextInput,
  Pressable,
} from "react-native";
import React, { useState } from "react";
import { StatusBar } from "expo-status-bar";
import theme from "../theme/theme";
import NavBar from "../Components/NavBar";
import SearchBar from "../Components/SearchBar";
import Heading from "../Components/Heading";
import AddBtn from "../Components/AddBtn";
import CardSetForm from "../Components/CardSetForm";

const Home = ({ navigation }) => {
  const [showInputModal, setShowInputModal] = useState(false);

  const handleShowModal = () => {
    setShowInputModal((prevState) => !prevState);
  };

  React.useLayoutEffect(() => {
    navigation.setOptions({
      headerShown: false,
    });
  }, [navigation]);

  return (
    <>
      <StatusBar style={theme.light_mode.status_bar} translucent={false} />
      <View style={styles.core_container}>
        <View style={theme.main_container}>
          <Heading text={"Flash Cards"} />
          <SearchBar search={(value) => console.log("search for : " + value)} />

          <View style={{ flex: 1 }}>
            <Text>library section</Text>
          </View>
          <AddBtn action={handleShowModal} />
          <Modal
            animationType="slide"
            visible={showInputModal}
            transparent={false}
          >
            <CardSetForm handleShowModal={handleShowModal} />
          </Modal>
        </View>
        <NavBar navigation={navigation} active_index={3}></NavBar>
      </View>
    </>
  );
};

export default Home;

const styles = StyleSheet.create({
  core_container: {
    flex: 1,
    backgroundColor: theme.light_mode.bg_light,
  },
});
