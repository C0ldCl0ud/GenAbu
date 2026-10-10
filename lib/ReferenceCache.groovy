import java.util.zip.GZIPInputStream
import groovy.json.JsonSlurper

class ReferenceCache {
    static boolean usableGzip(File path, String stubContent) {
        if (!path.isFile() || path.length() == 0) return false
        try {
            return new GZIPInputStream(new FileInputStream(path)).withCloseable { stream ->
                byte[] prefix = new byte[stubContent.getBytes('UTF-8').length + 1]
                int count = 0
                while (count < prefix.length) {
                    int n = stream.read(prefix, count, prefix.length - count)
                    if (n < 0) break
                    count += n
                }
                count > 0 && new String(prefix, 0, count, 'UTF-8') != stubContent
            }
        } catch (IOException ignored) {
            return false
        }
    }

    static boolean usableIndex(File indexDir) {
        def required = ['info.json', 'refseq.bin', 'refseq_offsets.json']
        if (!required.every { name ->
            def path = new File(indexDir, name)
            path.isFile() && path.length() > 0
        }) return false
        try {
            def info = new JsonSlurper().parse(new File(indexDir, 'info.json'))
            return info instanceof Map && info.stub != true
        } catch (Exception ignored) {
            return false
        }
    }
}
