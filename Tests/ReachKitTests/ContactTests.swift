import Foundation
import Testing
@testable import ReachKit

struct ContactTests {
    let sander = Contact(id: "1", namePrefix: "Mr", givenName: "Sander", middleName: "J", familyName: "Robijns",
                         nameSuffix: "Jr", organization: "Esforzado", jobTitle: "Architect",
                         fields: [ContactField(.phone, label: "mobile", value: "+31 6 1234 5678"),
                                  ContactField(.email, label: "work", value: "sander@example.com")])

    @Test func nameFirstThenLast() {
        #expect(sander.name() == "Sander J Robijns Jr")
    }

    @Test func nameLastFirst() {
        #expect(sander.name(lastFirst: true) == "Robijns Sander J Jr")
    }

    @Test func titleOnlyWhenAsked() {
        #expect(sander.name(showTitle: true) == "Mr Sander J Robijns Jr")
        #expect(sander.name(lastFirst: true, showTitle: true) == "Mr Robijns Sander J Jr")
    }

    @Test func missingPartsLeaveNoGaps() {
        #expect(Contact(id: "2", familyName: "Robijns").name(lastFirst: true, showTitle: true) == "Robijns")
        #expect(Contact(id: "3", namePrefix: "Dr", givenName: "Ada").name(showTitle: true) == "Dr Ada")
    }

    @Test func companyCardShowsTheCompany() {
        let acme = Contact(id: "4", organization: "Acme")
        #expect(acme.name(lastFirst: true, showTitle: true) == "Acme")
        #expect(acme.subtitle() == "")
        #expect(acme.initials == "A")
    }

    @Test func subtitleFollowsJobTitleSetting() {
        #expect(sander.subtitle() == "Esforzado")
        #expect(sander.subtitle(showJobTitle: true) == "Architect, Esforzado")
        let plain = Contact(id: "5", givenName: "Ada", fields: sander.fields)
        #expect(plain.subtitle(showJobTitle: true) == "sander@example.com")
    }

    @Test func fieldActions() {
        #expect(ContactField(.email, value: "a+b@example.com").action == .email(URL(string: "mailto:a%2Bb@example.com")!))
        #expect(ContactField(.url, value: "example.com").action == .open(URL(string: "https://example.com")!))
        #expect(ContactField(.address, value: "Damrak 1\nAmsterdam").action
                == .map(URL(string: "https://maps.apple.com/?q=Damrak%201,%20Amsterdam")!))
        #expect(ContactField(.url, value: "http://example.com/a").action == .open(URL(string: "http://example.com/a")!))
        #expect(ContactField(.url, value: "file:///Applications/Calculator.app").action == .copy)
        #expect(ContactField(.url, value: "x-other-app://run").action == .copy)
        #expect(ContactField(.phone, value: "+31 6").action == .copy)
        #expect(ContactField(.email, value: "not an address").action == .copy)
    }

    @Test func emailAddressCheck() {
        #expect(ContactField.isEmailAddress("sander@example.com"))
        #expect(!ContactField.isEmailAddress("sander"))
        #expect(!ContactField.isEmailAddress("sander robijns@example.com"))
    }

    @Test func initials() {
        #expect(sander.initials == "SR")
    }
}
