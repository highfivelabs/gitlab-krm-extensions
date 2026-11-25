// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

package extensions

import (
	"net/http"
	"strings"

	"github.com/highfivelabs/krm-rest-runtime/rest"
)

// Vendor is how the manager reaches GitLab.
var Vendor = &rest.Vendor{
	Name:           "gitlab",
	DefaultBaseURL: "https://gitlab.com/api/v4",
	CredentialKeys: []string{"token"},
	Authorize:      func(r *http.Request, c map[string]string) { r.Header.Set("PRIVATE-TOKEN", c["token"]) },
	// The GraphQL kinds' endpoint, /api/graphql, takes the place of the
	// REST API's /api/v4 at the end of the Connection's base URL.
	RESTPath: "/api/v4",
	// GitLab's GraphQL answers a missing object, or one the token may not
	// see, with this top-level error (and a 200); an unassign whose policy
	// project is gone, with this mutation error: unassigned already.
	NotFound: func(status int, body []byte) bool {
		b := string(body)
		return status == http.StatusOK && (strings.Contains(b, "does not exist or you don't have permission to perform this action") ||
			strings.Contains(b, "Policy project doesn't exist"))
	},
	// A project's pull mirror reads as 400 "The project is not mirrored"
	// until it is configured (and while it is disabled): not there yet, so
	// ProjectPullMirror configures it.
	NotFoundReq: func(method, path string, status int, _ []byte) bool {
		p, _, _ := strings.Cut(path, "?")
		return method == http.MethodGet && status == http.StatusBadRequest && strings.HasSuffix(p, "/mirror/pull")
	},
}
