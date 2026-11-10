.pragma library
.import QtQml as QtQml

// Creates a deferred domain (ADAPTER_CONTRACT §1) from a resolved URL and hands it to done(object).
// done() runs only with a real object: a component can be Ready while createObject() still fails
// (a required property left unset, an error in a binding at construction), and publishing that null
// would replace the contract placeholder. A failure is logged and the placeholder stays.
function create(parent, url, properties, done, label) {
    const component = Qt.createComponent(url);
    const finish = () => {
        if (component.status === QtQml.Component.Ready) {
            const object = component.createObject(parent, properties);
            if (object)
                done(object);
            else
                console.warn(label, url, "could not be created; keeping the placeholder", component.errorString());
        } else if (component.status === QtQml.Component.Error) {
            console.warn(label, url, component.errorString());
        }
    };
    if (component.status === QtQml.Component.Loading)
        component.statusChanged.connect(finish);
    else
        finish();
}
