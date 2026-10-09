import Darwin
import MachO

/// Resolves a non-exported symbol in an already-loaded system image. SkyLight's
/// bridged Space operation is a local C++ symbol, so dlsym cannot find it.
/// Uses the same LC_SYMTAB / __LINKEDIT approach as yabai's macho_dlsym.h.
enum LoadedMachOSymbol {
    static func find(_ symbol: String, in imagePath: String) -> UnsafeMutableRawPointer? {
        for index in 0..<_dyld_image_count() {
            guard let name = _dyld_get_image_name(index), String(cString: name) == imagePath,
                  let header = _dyld_get_image_header(index), header.pointee.magic == MH_MAGIC_64
            else { continue }
            return find(symbol, header: UnsafeRawPointer(header), slide: _dyld_get_image_vmaddr_slide(index))
        }
        return nil
    }

    private static func find(_ symbol: String, header: UnsafeRawPointer, slide: Int) -> UnsafeMutableRawPointer? {
        let image = header.load(as: mach_header_64.self)
        let commands = header.advanced(by: MemoryLayout<mach_header_64>.size)
        var offset = 0
        var linkedit: segment_command_64?
        var symtab: symtab_command?
        var executableSegments: [segment_command_64] = []

        for _ in 0..<image.ncmds {
            guard offset <= Int(image.sizeofcmds) - MemoryLayout<load_command>.size else { return nil }
            let pointer = commands.advanced(by: offset)
            let command = pointer.load(as: load_command.self)
            guard command.cmdsize >= MemoryLayout<load_command>.size,
                  Int(command.cmdsize) <= Int(image.sizeofcmds) - offset else { return nil }
            if command.cmd == LC_SEGMENT_64 {
                guard command.cmdsize >= MemoryLayout<segment_command_64>.size else { return nil }
                var segment = pointer.load(as: segment_command_64.self)
                let name = withUnsafeBytes(of: &segment.segname) { bytes in
                    String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
                }
                if name == "__LINKEDIT" { linkedit = segment }
                if segment.initprot & VM_PROT_EXECUTE != 0 { executableSegments.append(segment) }
            } else if command.cmd == LC_SYMTAB {
                guard command.cmdsize >= MemoryLayout<symtab_command>.size else { return nil }
                symtab = pointer.load(as: symtab_command.self)
            }
            offset += Int(command.cmdsize)
        }

        guard let linkedit, let symtab else { return nil }
        func mappedTable(offset: UInt32, size: UInt64) -> UnsafeRawPointer? {
            guard UInt64(offset) >= linkedit.fileoff else { return nil }
            let relative = UInt64(offset) - linkedit.fileoff
            guard relative <= linkedit.filesize, size <= linkedit.filesize - relative,
                  relative <= linkedit.vmsize, size <= linkedit.vmsize - relative,
                  linkedit.vmaddr <= UInt64(Int.max), relative <= UInt64(Int.max)
            else { return nil }
            let (base, overflow) = Int(linkedit.vmaddr).addingReportingOverflow(slide)
            let (address, overflow2) = base.addingReportingOverflow(Int(relative))
            guard !overflow, !overflow2 else { return nil }
            return UnsafeRawPointer(bitPattern: address)
        }

        guard let entries = mappedTable(offset: symtab.symoff, size: UInt64(symtab.nsyms) * UInt64(MemoryLayout<nlist_64>.stride)),
              let strings = mappedTable(offset: symtab.stroff, size: UInt64(symtab.strsize)) else { return nil }
        let expected = Array(symbol.utf8) + [0]
        for index in 0..<Int(symtab.nsyms) {
            let entry = entries.advanced(by: index * MemoryLayout<nlist_64>.stride).load(as: nlist_64.self)
            let stringOffset = Int(entry.n_un.n_strx)
            guard entry.n_type & UInt8(N_STAB) == 0,
                  entry.n_type & UInt8(N_TYPE) == UInt8(N_SECT),
                  stringOffset < Int(symtab.strsize), expected.count <= Int(symtab.strsize) - stringOffset
            else { continue }
            let name = UnsafeRawBufferPointer(start: strings.advanced(by: stringOffset), count: expected.count)
            guard name.elementsEqual(expected) else { continue }
            // Only resolve executable addresses inside this image, never data or undefined symbols.
            guard executableSegments.contains(where: {
                entry.n_value >= $0.vmaddr && entry.n_value - $0.vmaddr < $0.vmsize
            }), entry.n_value <= UInt64(Int.max) else { return nil }
            let (address, overflow) = Int(entry.n_value).addingReportingOverflow(slide)
            return overflow ? nil : UnsafeMutableRawPointer(bitPattern: address)
        }
        return nil
    }
}
