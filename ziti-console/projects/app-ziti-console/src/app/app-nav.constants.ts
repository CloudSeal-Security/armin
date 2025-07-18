/*
    Copyright NetFoundry Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

import {URLS} from "./app-urls.constants";
import {environment} from "./environments/environment";

export const OPEN_ZITI_NAVIGATOR = {
    groups: [
        {
            label: '',
            menuItems: [
                {
                    label: 'Dashboard',
                    route: URLS.ZITI_DASHBOARD,
                    iconClass: 'dashboard_icon',
                    selectedRoutes: [URLS.ZITI_DASHBOARD]
                }
            ]
        },
        {
            label: 'Core Components',
            menuItems: [
                {
                    label: 'Identities',
                    route: URLS.ZITI_IDENTITIES,
                    iconClass: 'identities-icon',
                    selectedRoutes: [URLS.ZITI_IDENTITIES]
                },
                {
                    label: 'Services',
                    route: URLS.ZITI_SERVICES,
                    iconClass: 'services-icon',
                    selectedRoutes: [URLS.ZITI_SERVICES]
                },
                {
                    label: 'Routers',
                    route: URLS.ZITI_ROUTERS,
                    iconClass: 'routers-icon',
                    selectedRoutes: [URLS.ZITI_ROUTERS]
                }
            ]
        },
        {
            label: 'Access Rules',
            menuItems: [
                {
                    label: 'Policies',
                    route: URLS.ZITI_SERVICE_POLICIES,
                    iconClass: 'icon-servicepolicy',
                    selectedRoutes: [URLS.ZITI_SERVICE_POLICIES]
                },
                {
                    label: 'Posture Checks',
                    route: URLS.ZITI_POSTURE_CHECKS,
                    iconClass: 'icon-posture',
                    selectedRoutes: [URLS.ZITI_POSTURE_CHECKS]
                }
            ]
        },
        {
            label: 'Management',
            menuItems: [
                {
                    label: 'Authentication',
                    route: URLS.ZITI_CERT_AUTHORITIES,
                    iconClass: 'authentication-icon',
<<<<<<< HEAD
                    selectedRoutes: [URLS.ZITI_CERT_AUTHORITIES],
                    hidden: true
=======
                    selectedRoutes: [URLS.ZITI_CERT_AUTHORITIES]
>>>>>>> 7d13daa (first commit)
                },
                {
                    label: 'Sessions',
                    route: URLS.ZITI_SESSIONS,
                    iconClass: 'sessions-icon',
<<<<<<< HEAD
                    selectedRoutes: [URLS.ZITI_SESSIONS],
                    hidden: true
=======
                    selectedRoutes: [URLS.ZITI_SESSIONS]
>>>>>>> 7d13daa (first commit)
                },
            ]
        }
    ]
}

export const CLASSIC_ZITI_NAVIGATOR = {
    groups: [
        {
            label: '',
            menuItems: [
                {
                    label: 'Dashboard',
                    route: URLS.ZITI_DASHBOARD,
                    iconClass: 'dashboard_icon',
                    selectedRoutes: [URLS.ZITI_DASHBOARD]
                },
                {
                    label: 'Identities',
                    route: URLS.ZITI_IDENTITIES,
                    iconClass: 'identities-icon',
                    selectedRoutes: [URLS.ZITI_IDENTITIES]
                },
                {
                    label: 'Recipies',
                    route: URLS.ZITI_RECIPES,
                    iconClass: 'icon-template',
                    selectedRoutes: [URLS.ZITI_RECIPES],
                    hidden: !environment.nodeIntegration
                },
                {
                    label: 'Services',
                    route: URLS.ZITI_SERVICES,
                    iconClass: 'services-icon',
                    selectedRoutes: [URLS.ZITI_SERVICES]
                },
                {
                    label: 'Configurations',
                    route: URLS.ZITI_CONFIGS,
                    iconClass: 'configurations-icon',
                    selectedRoutes: [URLS.ZITI_CONFIGS]
                },
                {
                    label: 'Policies',
                    route: URLS.ZITI_SERVICE_POLICIES,
                    iconClass: 'policies-icon',
                    selectedRoutes: [URLS.ZITI_SERVICE_POLICIES]
                },
                {
                    label: 'Routers',
                    route: URLS.ZITI_ROUTERS,
                    iconClass: 'routers-icon',
                    selectedRoutes: [URLS.ZITI_ROUTERS]
                },
                {
                    label: 'Authentication',
                    route: URLS.ZITI_CERT_AUTHORITIES,
                    iconClass: 'authentication-icon',
<<<<<<< HEAD
                    selectedRoutes: [URLS.ZITI_CERT_AUTHORITIES],
                    hidden: true
=======
                    selectedRoutes: [URLS.ZITI_CERT_AUTHORITIES]
>>>>>>> 7d13daa (first commit)
                },
                {
                    label: 'Sessions',
                    route: URLS.ZITI_SESSIONS,
                    iconClass: 'sessions-icon',
<<<<<<< HEAD
                    selectedRoutes: [URLS.ZITI_SESSIONS],
                    hidden: true
=======
                    selectedRoutes: [URLS.ZITI_SESSIONS]
>>>>>>> 7d13daa (first commit)
                },
            ]
        }
    ]
}
