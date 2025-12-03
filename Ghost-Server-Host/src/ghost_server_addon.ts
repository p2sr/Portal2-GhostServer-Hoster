import path from "path";
const addon = require(path.join(__dirname, "..", "addon"));

export class Client {
    id: number;
    name: string;
    isSpectator: boolean;
}

export class Whitelist {
    enabled: boolean;
    entries: WhitelistEntry[];
}

export class WhitelistEntry {
    type: "name" | "ip";
    value: string;
}

export const list: () => Client[] = addon.list;

export const startServer: (port: number) => string = addon.startServer;
export const exit: () => string = addon.exit;

export const startCountdown: (preCommands: string, postCommands: string, duration: number) => undefined = addon.startCountdown;
export const serverMessage: (message: string) => undefined = addon.serverMessage;

export const disconnect: (name: string) => undefined = addon.disconnect;
export const disconnectId: (id: number) => undefined = addon.disconnectId;

export const ban: (name: string) => undefined = addon.ban;
export const banId: (id: number) => undefined = addon.banId;

export const setAcceptingPlayers: (value: boolean | undefined) => undefined = addon.setAcceptingPlayers;
export const getAcceptingPlayers: () => boolean = addon.getAcceptingPlayers;

export const setAcceptingSpectators: (value: boolean | undefined) => undefined = addon.setAcceptingSpectators;
export const getAcceptingSpectators: () => boolean = addon.getAcceptingSpectators;

export const getWhitelist: () => Whitelist = addon.getWhitelist;
export const setWhitelistEnabled: (boolean) => undefined = addon.setWhitelistEnabled;
export const addNameToWhitelist: (name: string) => undefined = addon.addNameToWhitelist;
export const addIpToWhitelist: (ip: string) => undefined = addon.addIpToWhitelist;
export const removeNameFromWhitelist: (name: string) => undefined = addon.removeNameFromWhitelist;
export const removeIpFromWhitelist: (ip: string) => undefined = addon.removeIpFromWhitelist;
