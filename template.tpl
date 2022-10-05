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
  },
  {
    "type": "RADIO",
    "name": "appType",
    "displayName": "App Type",
    "radioItems": [
      {
        "value": "sbi",
        "displayValue": "Search"
      },
      {
        "value": "vsr",
        "displayValue": "Recommendations"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "sbi",
    "help": "Search or Recommendations Widget"
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
const getUrl = require('getUrl');
const getContainerVersion = require('getContainerVersion');
const copyFromDataLayer = require('copyFromDataLayer');
const getQueryParameters = require('getQueryParameters');

const SCRIPT_VERSION = '0.1.0';
const CONTAINER_VERSION = getContainerVersion();

const VS_LAYER_REF = 'visenzeLayer';
const LAST_CLICK_REF = 'visenze_widget_last_click';
const APP_DEPLOY_CONFIGS_REF = 'visenzeAppDeployConfigs';
const WIDGET_PID_REF = 'visenzeWidgetsPid';

const env = CONTAINER_VERSION.environmentName === 'production' || data.env === 'production' ? 'production' : 'staging';
const appType = data.appType;

const paramsMap = {
  staging: {
    sbi: {
      widgetUrl: 'https://cdn-staging.visenze.com/widgets/dist/js/productsearch/staging/staging.deploy_script.2.0.3.js',
      analyticsUrl: 'https://search-dev.visenze.com',
    },
    vsr: {
      widgetUrl: 'https://cdn-staging.visenze.com/widgets/dist/js/productsearch/staging/staging.deploy_script.2.0.3.js',
      analyticsUrl: 'https://search-dev.visenze.com',
    },
  },
  production: {
    sbi: {
      widgetUrl: 'https://cdn.visenze.com/widgets/dist/js/productsearch/vsr_embedded.2.0.1.js',
      analyticsUrl: 'https://search-dev.visenze.com',
    },
    vsr: {
      widgetUrl: 'https://cdn.visenze.com/widgets/dist/js/productsearch/vsr_embedded.2.0.1.js',
      analyticsUrl: 'https://search-dev.visenze.com',
    },
  },
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
if (data.integrationType !== 'widget' && !productId) {
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


const sendWidgetEvent = (eventName, body) => {
  const storedEvent = JSON.parse(localStorage.getItem(LAST_CLICK_REF)) || {};
  if (!(storedEvent && storedEvent.queryId && storedEvent.pid)) {
    log('Unable to retrieve last clicked widget for event: ', eventName);
    data.gtmOnFailure();
    return;
  }

  const placementId = storedEvent.pid;
  body.queryId = storedEvent.queryId;


  // initialize visenzeLayer if not available
  const vsLayerRef = copyFromWindow(VS_LAYER_REF);
  if (!vsLayerRef) {
    setInWindow(VS_LAYER_REF, []);
  }
  // call visenzeLayer.push method, with event
  const vsLayerPushMethod = VS_LAYER_REF + '.push';
  const vsLayerBody = {
    action: 'send',
    placementId: placementId,
    params: [eventName, body],
  };
  callInWindow(vsLayerPushMethod, vsLayerBody);
};


const initWidget = () => {
  const appKey = data.appKey;
  let deployScriptUrl = paramsMap[env][appType].analyticsUrl + '/v1/deploy-configs?app_key=' + appKey + '&gtm_deploy=true';

  const previewId = getQueryParameters('visenzePreviewId');
  if (previewId) {
    deployScriptUrl = deployScriptUrl + '&preview_id=' + previewId; 
  }
  const debugId = getQueryParameters('visenzeDebugId');
  if (previewId) {
    deployScriptUrl = deployScriptUrl + '&debug_id=' + debugId; 
  }

  const widgetUrl = paramsMap[env][appType].widgetUrl;

  const successFn = () => {
    log('successfully loaded widget');

    // initialize visenzeLayer if it does not exist
    const vsLayer = copyFromWindow(VS_LAYER_REF);
    if (!vsLayer) {
      setInWindow(VS_LAYER_REF, []);
    }

    const deploySuccessFn = () => {
      // Call data.gtmOnSuccess when the tag is done deploying script.
      data.gtmOnSuccess();
    };
    const deployFailureFn = () => {
      log('unable to load deploy script, url=', deployScriptUrl, ', id=', previewId);
      data.gtmOnFailure();
    };

    injectScript(deployScriptUrl, deploySuccessFn, deployFailureFn, deployScriptUrl);
  };

  const failureFn = () => {
    log('unable to load widget script: ', widgetUrl);
    data.gtmOnFailure();
  };

  setInWindow(WIDGET_PID_REF, productId);
  injectScript(widgetUrl, successFn, failureFn, widgetUrl);
};


const shouldSendEvent = () => {
  const appDeployConfigs = copyFromWindow(APP_DEPLOY_CONFIGS_REF);
  const deployType = appDeployConfigs && appDeployConfigs[data.appKey] && appDeployConfigs[data.appKey].deploy_type_id;
  return deployType === 1 || deployType === '1';
};


const sendAtcEvent = () => {
  if (shouldSendEvent()) {
    const EVENT_NAME = 'add_to_cart';
    sendWidgetEvent(EVENT_NAME, { pid: productId });
  } else {
    data.gtmOnFailure();
  }
};


const sendTransactionEvent = () => {
  if (shouldSendEvent()) {
    const EVENT_NAME = 'transaction';
    const dataLayerArr = copyFromWindow('dataLayer');
    const orderValueKeys = data.orderValueFieldName.split('.');
    const orderValue = getFromDataLayers(dataLayerArr, getProductIdByNestedKey, orderValueKeys);

    sendWidgetEvent(EVENT_NAME, { pid: productId, order_value: orderValue });
  } else {
    data.gtmOnFailure();
  }
};


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
                    "string": "visenzeWidgets"
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
                    "string": "visenzeAppDeployConfigs"
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
                    "string": "visenzeLayer"
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
                    "string": "visenzeLayer.push"
                  },
                  {
                    "type": 8,
                    "boolean": false
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
                    "string": "visenzeWidgetsPid"
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
                "string": "https://*.visenze.com/"
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
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "vs_last_clicked_result"
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
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "visenze_widget_last_click"
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
        "publicId": "get_url",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "isRequired": true
  }
]


___TESTS___



___NOTES___

Created on 04/10/2022, 10:50:22


