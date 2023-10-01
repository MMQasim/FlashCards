import { StyleSheet, Text, View, Modal } from "react-native";
import { StatusBar } from "expo-status-bar";
import React from "react";
import { useEffect, useState } from "react";
import theme from "../theme/theme";
import SearchBar from "../Components/SearchBar";
import NavBar from "../Components/NavBar";
import Heading from "../Components/Heading";
import AddBtn from "../Components/AddBtn";
import * as SQLite from "expo-sqlite";
import conf from "../conf";
import EmptyNote from "../Components/EmptyNote";
import CardForm from "../Components/CardForm";

const Topic = ({ route, navigation }) => {
  const { cardSetId, cardSetName } = route.params;
  const DB = SQLite.openDatabase(conf.LocalDB);
  const [cards, setCards] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showInputModal, setShowInputModal] = useState(false);

  const getCardFromDb = () => {
    DB.transaction((tx) => {
      tx.executeSql(
        "SELECT * FROM Card WHERE CardSetUuid = ?",
        [cardSetId],
        (txtObj, resObj) => {
          setCards(resObj.rows._array);
          setIsLoading(false);
        },
        (txtObj, errorObj) => {
          console.log(errorObj);
        }
      );
    });
  };
  useEffect(() => {
    getCardFromDb();
  }, []);

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
      <Modal visible={isLoading}>
        <Text>Loading DB</Text>
      </Modal>
      <StatusBar style={theme.light_mode.status_bar} translucent={false} />
      <View style={styles.core_container}>
        <View style={theme.main_container}>
          <Heading text={cardSetName} />
          <SearchBar />
          <View style={{ flex: 1 }}>
            {cards.length == 0 ? (
              <EmptyNote text={"Your Card Set Is Empty, Please Add Cards."} />
            ) : (
              <></>
            )}
          </View>
          <AddBtn action={handleShowModal} />
          <Modal
            animationType="slide"
            visible={showInputModal}
            transparent={false}
          >
            <CardForm
              onClose={() => {
                handleShowModal();
                getCardFromDb();
              }}
              typeId={cardSetId}
            />
          </Modal>
        </View>
        <NavBar navigation={navigation} active_index={0}></NavBar>
      </View>
    </>
  );
};

export default Topic;

const styles = StyleSheet.create({
  core_container: {
    flex: 1,
    backgroundColor: theme.light_mode.bg_light,
  },
});
