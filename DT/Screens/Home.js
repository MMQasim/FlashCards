import { StyleSheet, Text, View, Modal, FlatList } from "react-native";
import React, { useState, useEffect } from "react";
import { StatusBar } from "expo-status-bar";
import theme from "../theme/theme";
import NavBar from "../Components/NavBar";
import SearchBar from "../Components/SearchBar";
import Heading from "../Components/Heading";
import AddBtn from "../Components/AddBtn";
import CardSetForm from "../Components/CardSetForm";
import CardSetItem from "../Components/CardSetItem";
import * as SQLite from "expo-sqlite";
import conf from "../conf";

const Home = ({ navigation }) => {
  const DB = SQLite.openDatabase(conf.LocalDB);
  const [cards, setCards] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showInputModal, setShowInputModal] = useState(false);

  const getCardSetFromDb = () => {
    DB.transaction((tx) => {
      tx.executeSql(
        "SELECT * FROM CardSet",
        null,
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
    getCardSetFromDb();
  }, []);

  const handleShowModal = () => {
    setShowInputModal((prevState) => !prevState);
  };

  React.useLayoutEffect(() => {
    navigation.setOptions({
      headerShown: false,
    });
  }, [navigation]);

  const onDeleteHandler = (id) => {
    DB.transaction((tx) => {
      tx.executeSql(
        "DELETE FROM CardSet WHERE uuid = ?",
        [id],
        (txtObj, resObj) => {
          setCards((prevState) => {
            return prevState.filter((card) => card.uuid !== id);
          });
        },
        (txtObj, errorObj) => {
          console.log(errorObj);
        }
      );
    });
  };

  return (
    <>
      <Modal visible={isLoading}>
        <Text>Loading DB</Text>
      </Modal>
      <StatusBar style={theme.light_mode.status_bar} translucent={false} />
      <View style={styles.core_container}>
        <View style={theme.main_container}>
          <Heading text={"Flash Cards"} />
          <SearchBar search={(value) => console.log("search for : " + value)} />
          <View style={{ flex: 1 }}>
            {cards.length == 0 ? (
              <View>
                <Text>Your Card Set Is Empty, Please Add Card Set.</Text>
              </View>
            ) : (
              <></>
            )}
            <FlatList
              data={cards}
              renderItem={(itemData) => {
                return (
                  <CardSetItem
                    name={itemData.item.Name}
                    category={itemData.item.Category}
                    detail={itemData.item.Detail}
                    onDeleteAction={() => onDeleteHandler(itemData.item.uuid)}
                  />
                );
              }}
              keyExtractor={(item, index) => {
                return item.uuid;
              }}
            />
          </View>

          <AddBtn action={handleShowModal} />
          <Modal
            animationType="slide"
            visible={showInputModal}
            transparent={false}
          >
            <CardSetForm
              handleShowModal={() => {
                handleShowModal();
                getCardSetFromDb();
              }}
            />
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
