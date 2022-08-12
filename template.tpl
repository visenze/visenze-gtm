___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "ViSenze widget integration - dev",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Deploy ViSenze solutions via GTM, enabling users in bypassing any development resources, launch and test ViSenze solutions as fast as possible.\n\nTODO: Gallery TOS not accepted yet",
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "appKey",
    "displayName": "appKey",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "placementId",
    "displayName": "placementId (To be removed with upcoming feature)",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "POSITIVE_NUMBER"
      }
    ]
  },
  {
    "type": "SELECT",
    "name": "integrationType",
    "displayName": "Integration Type",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "widget",
        "displayValue": "Load Widget(s)"
      },
      {
        "value": "event.atc",
        "displayValue": "Add To Cart Events"
      },
      {
        "value": "event.trans",
        "displayValue": "Transaction Events"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "widget",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "productIdFieldName",
    "displayName": "GTM variable name for ProductId",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "e.g. ecommerce.items.0.item_id"
  },
  {
    "type": "TEXT",
    "name": "cssSelector",
    "displayName": "CSS Selector (To be removed with upcoming feature)",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "e.g. \u0027.vsr-embedded-oos\u0027",
    "enablingConditions": [
      {
        "paramName": "integrationType",
        "paramValue": "widget",
        "type": "EQUALS"
      }
    ]
  },
  {
    "type": "SELECT",
    "name": "env",
    "displayName": "Environment",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "production",
        "displayValue": "Production"
      },
      {
        "value": "staging",
        "displayValue": "Staging"
      }
    ],
    "simpleValueType": true,
    "help": "Temporary variable to control widget env (staging / production)",
    "defaultValue": "staging"
  },
  {
    "type": "TEXT",
    "name": "orderValueFieldName",
    "displayName": "GTM variable name for order value in Checkout event",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "integrationType",
        "paramValue": "event.trans",
        "type": "EQUALS"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "deployVersion",
    "displayName": "Widget Deployment version (TBC)",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "env",
        "paramValue": "staging",
        "type": "EQUALS"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

/**
 * This template injects appropriate ViSenze widget(s) on customers' PDP,
 * provided that:
 * 1. Customers provide identifier for PDP page for this script to load
 *    the widget at the correct location
 * 2. Template is injected to 'Page Load - DOM Ready' trigger
 */
const log = require('logToConsole');
const localStorage = require('localStorage');
const JSON = require('JSON');
const Object = require('Object');
const makeNumber = require('makeNumber');
const makeString = require('makeString');
const queryPermission = require('queryPermission');
const injectScript = require('injectScript');
const callInWindow = require('callInWindow');
const copyFromWindow = require('copyFromWindow');
const setInWindow = require('setInWindow');
const getContainerVersion = require('getContainerVersion');
const copyFromDataLayer = require('copyFromDataLayer');

const SCRIPT_VERSION = '0.1';
const CONTAINER_VERSION = getContainerVersion();
const ATTR_TO_SELECT = 'data-pid';
// TODO: confirm stored format for Last Clicked event in Localstorage following ES-5475 implementation
const LAST_CLICK_REF = 'vs_last_clicked_result';
const WIDGET_EVENT_REF = 'vsWidgetsFn';
// TODO: hide data.env field from Production GTM template after POC
const env = CONTAINER_VERSION.environmentName === 'production' || data.env === 'production' ? 'production' : 'staging';

// TODO: update script URL after ES-5474 implementation
const paramsMap = {
  staging: 'https://cdn.visenze.com/widgets/dist/js/productsearch/staging/vsr_embedded.staging.js',
  production: 'https://cdn.visenze.com/widgets/dist/js/productsearch/vsr_embedded.2.0.1.js',
};


const getFromDataLayers = (dataLayerArr, fn, args) => {
  for (const dl of dataLayerArr) {
    const val = args ? fn(dl, args) : fn(dl);
    if (val) {
      return val;
    }
  }

  return '';
};

const getProductIdByKey = (dl) => {
  const productIdField = data.productIdFieldName;
  return dl[productIdField] || '';
};

const getProductIdByNestedKey = (dl, keys) => {
  let productId = '';
  const key = keys[0];

  const keyIntValue = makeNumber(key);
  if ((keyIntValue || keyIntValue === 0) && typeof dl !== 'string') {
    for (const el of dl) {
      const productIdToAdd = keys.length === 1 ? makeString(el) : getProductIdByNestedKey(el, keys.slice(1));
      productId = productId + (productId ? ',' : '') + productIdToAdd;
    }

    return productId;
  }

  const nestedValue = dl[key];
  if (!nestedValue) {
    return '';
  }

  return keys.length > 1 ? getProductIdByNestedKey(nestedValue, keys.slice(1)) : makeString(nestedValue);
};

const getProductId = () => {
  const dataLayerArr = copyFromWindow('dataLayer');
  const productIdByKey = getFromDataLayers(dataLayerArr, getProductIdByKey, null);
  if (productIdByKey) {
    return productIdByKey;
  }

  const objKeys = data.productIdFieldName.split('.');
  return getFromDataLayers(dataLayerArr, getProductIdByNestedKey, objKeys);
};


const productId = getProductId();
if (!productId) {
  log('event not triggered, event =', data.event, ', integration type =', data.integrationType);
  data.gtmOnSuccess();
  return;
}


log({
  version: SCRIPT_VERSION,
  container: CONTAINER_VERSION,
});

const validateFnInit = (fn) => {
  if (!copyFromWindow(fn)) {
    log('Unable to init event from window: ', fn, ', version =', SCRIPT_VERSION);
    data.gtmOnFailure();
  }
};


/**
 * TODO: since GTM layer is unable to read widget objects,
 * this method assumes there exists a @function vsWidgetsFn on the window layer,
 * which sends event to correct widget.
 *
 * Mock implementation of vsWidgetsFn / vsWidgets via Console:

const w1 = initVSRembedded({appSettings: {appKey: 'xxx', placementId: xxx}, displaySettings: {vsrSelector: '.ps-vsr-widget-embedded-334'}, onTrackingCallback: (action, params) => {console.log('onTrackingCallback: ', action, params);}});
w1.then((w) => {
  window.vsWidgets = [w];
  window.vsWidgetsFn = (appKey, placementId, eventName, body) => {
    // assuming all widgets are stored under vsWidgets variable

    const w = window.vsWidgets.find((widget) => (widget.settings.appKey === appKey && widget.settings.placementId === placementId));
    if (!w) { return null; }
    w.send(eventName, body);
    return 'ok';
  };
});

 *
 */
const sendWidgetEvent = (eventName, body) => {
  // TODO: remove log
  log('eventName=', eventName, ', body=', body);
  const vsWidgets = copyFromWindow('vsWidgets');
  log('vsWidgets=', vsWidgets);

  // TODO: remove if doesn't work
  if (vsWidgets) {
    for (const w in vsWidgets) {
      if (w && w.send) {
        log('iterating through vsWidgets, widget=', w);
        w.send(eventName, body);
      }
    }
  }

  // TODO: add localStorage Read perms for key after ES-5475 implementation
  const storedEvent = JSON.parse(localStorage.getItem(LAST_CLICK_REF)) || {};

  if (!(storedEvent && storedEvent.queryId && storedEvent.pid)) {
    log('Unable to retrieve last clicked widget for event: ', eventName);
    data.gtmOnFailure();
    return;
  }

  body.queryId = storedEvent.queryId;
  body.placement_id = storedEvent.pid;

  const val = callInWindow(WIDGET_EVENT_REF, data.appKey, storedEvent.pid, eventName, body);
  log('vsWidgetsFn return value:', val);

  data.gtmOnSuccess();
};


const initWidget = () => {
  const config = {
    appSettings: {
      appKey: data.appKey,
      // TODO: remove after ES-5474 implementation
      placementId: data.placementId,
    },
    // TODO: hard-coded configs, to be removed with ES-5474
    // for now, use this to bind widget to <div class="vsr-embedded-oos"> element
    // that has been manually injected in the DOM
    displaySettings: {
      vsrSelector: data.cssSelector,
    },
  };

  // Dev test on widget https://dashboard-v2-staging-bz.visenze.com/302/recommendations/app/2009/placement/2731/widget-integrate
  // TODO: staging/production widget URL, based on environment
  const widgetUrl = paramsMap[env];

  const successFn = () => {
    log('successfully loaded widget');
    // TODO: confirm new method name for initializing widget(s) following ES-5475 implementation
    const fn = 'initVSRembedded';
    validateFnInit(fn);
    callInWindow(fn, config);
    // Call data.gtmOnSuccess when the tag is finished.
    data.gtmOnSuccess();
  };

  const failureFn = () => {
    log('unable to load widget script: ', widgetUrl);
    data.gtmOnFailure();
  };

  injectScript(widgetUrl, successFn, failureFn, widgetUrl);
};


const sendAtcEvent = () => {
  const EVENT_NAME = 'add_to_cart';
  sendWidgetEvent(EVENT_NAME, { product_id: productId });
};


const sendTransactionEvent = () => {
  const EVENT_NAME = 'transaction';

  const dataLayerArr = copyFromWindow('dataLayer');
  const orderValueKeys = data.orderValueFieldName.split('.');
  const orderValue = getFromDataLayers(dataLayerArr, getProductIdByNestedKey, orderValueKeys);

  sendWidgetEvent(EVENT_NAME, { product_id: productId, order_value: orderValue });
};


// TODO: Code supports integration with VSR embedded widget only, as of ES-5393, until ES-5474 implementation is done
switch (data.integrationType) {
  case 'widget': return initWidget();
  case 'event.atc': return sendAtcEvent();
  case 'event.trans': return sendTransactionEvent();
  default: data.gtmOnFailure();
}


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "all"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ga"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ga.q"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ga.l"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "initVSRpopup"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "dataLayer"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "initVSRembedded"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "vsWidgetsFn"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "vsLastClickEvent"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "vsWidgets"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "inject_script",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://cdn.visenze.com/"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_container_data",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_data_layer",
        "versionId": "1"
      },
      "param": []
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_local_storage",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "vsLastClickEvent"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: testTransactionEvent_multipleProductIds
  code: |-
    const mockData = {
      appKey: 'asdf',
      placementId: '1234',
      integrationType: 'event.trans',
      productIdFieldName: 'Product_SKU',
      orderValueFieldName: 'transactionProducts.0.sku',
    };

    const dataLayers = [productIdData, transactionData];

    mock('copyFromWindow', function (windowVar) {
      switch (windowVar) {
        case DATA_LAYER_WINDOW_FIELD: return dataLayers;
        default: return null;
      }
    });

    runCode(mockData);

    const widgetEventValue = {
      product_id: 'product_123',
      order_value: 'DD44,AA1243544',
    };

    assertApi('gtmOnSuccess').wasCalled();
    assertApi('copyFromWindow').wasCalledWith(DATA_LAYER_WINDOW_FIELD);
- name: testAtcEvent
  code: |-
    const mockData = {
      appKey: 'asdf',
      placementId: '1234',
      integrationType: 'event.atc',
      productIdFieldName: 'Product_SKU',
    };

    const dataLayers = [productIdData];

    mock('copyFromWindow', function (windowVar) {
      switch (windowVar) {
        case DATA_LAYER_WINDOW_FIELD: return dataLayers;
        default: return null;
      }
    });

    runCode(mockData);

    assertApi('gtmOnSuccess').wasCalled();
    assertApi('copyFromWindow').wasCalledWith(DATA_LAYER_WINDOW_FIELD);
- name: testWidgetEvent
  code: |-
    const INIT_WIDGET_FN = 'initVSRembedded';
    const mockData = {
      appKey: 'asdf',
      placementId: '1234',
      integrationType: 'widget',
      productIdFieldName: 'Product_SKU',
      cssSelector: '.vsr-embedded-oos',
    };

    const dataLayers = [productIdData];
    const config = {
      appSettings: {
        appKey: mockData.appKey,
        placementId: mockData.placementId,
      },
      displaySettings: {
        vsrSelector: mockData.cssSelector,
      },
    };
    const mockWidget = {};

    mock('copyFromWindow', function (windowVar) {
      switch (windowVar) {
        case DATA_LAYER_WINDOW_FIELD: return dataLayers;
        case INIT_WIDGET_FN: return (() => ({}));
        default: return null;
      }
    });

    runCode(mockData);

    assertApi('gtmOnSuccess').wasCalled();
    assertApi('copyFromWindow').wasCalledWith(DATA_LAYER_WINDOW_FIELD);
    assertApi('copyFromWindow').wasCalledWith(INIT_WIDGET_FN);
    assertApi('callInWindow').wasCalledWith(INIT_WIDGET_FN, config);
    assertApi('setInWindow').wasCalled();
setup: "const localStorage = require('localStorage');\nconst json = require('JSON');\n\
  \nconst DATA_LAYER_WINDOW_FIELD = 'dataLayer';\nconst LAST_CLICK_REF = 'vsLastClickEvent';\n\
  \nconst transactionData = {\n  transactionId: '1234',\n  transactionAffiliation:\
  \ 'Acme Clothing',\n  transactionTotal: 38.26, \n  transactionTax: 1.29,\n  transactionShipping:\
  \ 5,\n  transactionProducts: [\n    {\n      sku: 'DD44',\n      name: 'T-Shirt',\n\
  \      category: 'Apparel',\n      price: 11.99,  \n      quantity: 1 \n    },\n\
  \    {\n      sku: 'AA1243544',\n      name: 'Socks',\n      category: 'Apparel',\n\
  \      price: 9.99,\n      quantity: 2\n    }\n  ]\n};\n\nconst productIdData =\
  \ {\n  'Product_SKU': 'product_123',\n};\n\nconst lastClickedEvent = {\n  queryId:\
  \ 'xxx',\n  placement_id: 123,\n};\n\n// set LocalStorage permission for LAST_CLICKED_REF\
  \ to r/w before starting tests\nlocalStorage.setItem(LAST_CLICK_REF, json.stringify(lastClickedEvent));\n"


___NOTES___

Created on 12/08/2022, 14:37:37


