let registeredHost = null;

export function registerHost(host) {
  if (registeredHost) {
    throw new Error("a Selene UI component host is already registered");
  }
  for (const operation of ["apply"]) {
    if (typeof host?.[operation] !== "function") {
      throw new TypeError(`Selene UI component host is missing ${operation}()`);
    }
  }
  registeredHost = host;
  return () => {
    if (registeredHost === host) registeredHost = null;
  };
}

export function apply(entity, mutations) {
  if (!registeredHost) {
    throw new Error("the Selene UI component host has been unregistered");
  }
  return registeredHost.apply(entity, mutations);
}
