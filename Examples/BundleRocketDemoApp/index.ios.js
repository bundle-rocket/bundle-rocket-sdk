/**
 * @file Bundle Rocket App
 * @author cxtom (cxtom2010@gmail.com)
 */

const React = require('react-native');
const {
    AppRegistry,
    StyleSheet,
    Text,
    View
} = React;
const BundleRocket = require('bundle-rocket');

const styles = StyleSheet.create({
    container: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: '#F5FCFF'
    },
    welcome: {
        fontSize: 20,
        textAlign: 'center',
        margin: 10
    },
    instructions: {
        textAlign: 'center',
        color: '#333333',
        marginBottom: 5
    }
});

const BundleRocketDemoApp = React.createClass({

    componentDidMount() {
        BundleRocket.sync();
    },

    render() {

        return (
            <View style={styles.container}>
                <Text style={styles.welcome}>
                    Welcome to React Native!
                </Text>
                <Text style={styles.instructions}>
                    To get started, edit index.ios.js
                </Text>
                <Text style={styles.instructions}>
                    Press Cmd+R to reload,{'\n'}
                    Cmd+D or shake for dev menu
                </Text>
            </View>
        );
    }
});

AppRegistry.registerComponent('BundleRocketDemoApp', () => BundleRocketDemoApp);
